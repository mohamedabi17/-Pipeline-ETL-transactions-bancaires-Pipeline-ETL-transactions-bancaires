"""
MinIO Storage Manager
Upload/download data to MinIO (S3 alternative)
"""

import json
import logging
from pathlib import Path
from typing import List
from minio import Minio
from minio.error import S3Error
import argparse

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class MinIOManager:
    """Manage files in MinIO storage"""
    
    def __init__(self, config_path: str = 'config/minio_config.json'):
        """Initialize MinIO client"""
        
        with open(config_path, 'r') as f:
            config = json.load(f)['minio']
        
        self.config = config
        self.client = Minio(
            config['endpoint'],
            access_key=config['access_key'],
            secret_key=config['secret_key'],
            secure=config['secure']
        )
        
        self.buckets = config['buckets']
        logger.info(f"✓ Connected to MinIO at {config['endpoint']}")
    
    def create_buckets(self):
        """Create required buckets if they don't exist"""
        
        for bucket_type, bucket_name in self.buckets.items():
            try:
                if not self.client.bucket_exists(bucket_name):
                    self.client.make_bucket(bucket_name)
                    logger.info(f"✓ Created bucket: {bucket_name}")
                else:
                    logger.info(f"✓ Bucket exists: {bucket_name}")
            except S3Error as e:
                logger.error(f"Error creating bucket {bucket_name}: {e}")
    
    def upload_file(self, local_path: str, bucket_name: str, object_name: str = None):
        """Upload file to MinIO"""
        
        if object_name is None:
            object_name = Path(local_path).name
        
        try:
            self.client.fput_object(bucket_name, object_name, local_path)
            logger.info(f"✓ Uploaded: {local_path} -> {bucket_name}/{object_name}")
        except S3Error as e:
            logger.error(f"Upload failed: {e}")
    
    def upload_directory(self, local_dir: str, bucket_name: str, prefix: str = ""):
        """Upload entire directory to MinIO"""
        
        local_path = Path(local_dir)
        
        for file_path in local_path.rglob('*'):
            if file_path.is_file():
                relative_path = file_path.relative_to(local_path)
                object_name = f"{prefix}/{relative_path}" if prefix else str(relative_path)
                object_name = object_name.replace('\\', '/')
                
                self.upload_file(str(file_path), bucket_name, object_name)
    
    def download_file(self, bucket_name: str, object_name: str, local_path: str):
        """Download file from MinIO"""
        
        try:
            Path(local_path).parent.mkdir(parents=True, exist_ok=True)
            self.client.fget_object(bucket_name, object_name, local_path)
            logger.info(f"✓ Downloaded: {bucket_name}/{object_name} -> {local_path}")
        except S3Error as e:
            logger.error(f"Download failed: {e}")
    
    def list_objects(self, bucket_name: str, prefix: str = None) -> List[str]:
        """List objects in bucket"""
        
        try:
            objects = self.client.list_objects(bucket_name, prefix=prefix, recursive=True)
            object_names = [obj.object_name for obj in objects]
            return object_names
        except S3Error as e:
            logger.error(f"List failed: {e}")
            return []
    
    def delete_object(self, bucket_name: str, object_name: str):
        """Delete object from MinIO"""
        
        try:
            self.client.remove_object(bucket_name, object_name)
            logger.info(f"✓ Deleted: {bucket_name}/{object_name}")
        except S3Error as e:
            logger.error(f"Delete failed: {e}")
    
    def get_bucket_stats(self, bucket_name: str):
        """Get bucket statistics"""
        
        try:
            objects = self.client.list_objects(bucket_name, recursive=True)
            total_size = 0
            count = 0
            
            for obj in objects:
                total_size += obj.size
                count += 1
            
            return {
                'bucket': bucket_name,
                'object_count': count,
                'total_size_mb': total_size / (1024 * 1024)
            }
        except S3Error as e:
            logger.error(f"Stats failed: {e}")
            return None


def main():
    parser = argparse.ArgumentParser(description='MinIO Storage Manager')
    parser.add_argument('action', choices=['init', 'upload', 'download', 'list', 'stats'],
                       help='Action to perform')
    parser.add_argument('--bucket', type=str, help='Bucket name')
    parser.add_argument('--local', type=str, help='Local path')
    parser.add_argument('--remote', type=str, help='Remote object name')
    parser.add_argument('--prefix', type=str, help='Object prefix for listing')
    
    args = parser.parse_args()
    
    manager = MinIOManager()
    
    if args.action == 'init':
        manager.create_buckets()
    
    elif args.action == 'upload':
        if not args.bucket or not args.local:
            print("Error: --bucket and --local are required")
            return
        
        local_path = Path(args.local)
        if local_path.is_dir():
            manager.upload_directory(args.local, args.bucket, args.remote or "")
        else:
            manager.upload_file(args.local, args.bucket, args.remote)
    
    elif args.action == 'download':
        if not args.bucket or not args.remote or not args.local:
            print("Error: --bucket, --remote, and --local are required")
            return
        manager.download_file(args.bucket, args.remote, args.local)
    
    elif args.action == 'list':
        if not args.bucket:
            print("Error: --bucket is required")
            return
        objects = manager.list_objects(args.bucket, args.prefix)
        print(f"\nObjects in {args.bucket}:")
        for obj in objects:
            print(f"  - {obj}")
    
    elif args.action == 'stats':
        for bucket_name in manager.buckets.values():
            stats = manager.get_bucket_stats(bucket_name)
            if stats:
                print(f"\n{stats['bucket']}:")
                print(f"  Objects: {stats['object_count']}")
                print(f"  Size: {stats['total_size_mb']:.2f} MB")


if __name__ == '__main__':
    main()

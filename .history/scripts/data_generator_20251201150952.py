"""
Banking Transaction Data Generator
Generates realistic banking transaction data for ETL testing
"""

import json
import random
import csv
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict
import argparse
from faker import Faker
import logging
from tqdm import tqdm

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Faker for realistic data
fake = Faker('fr_FR')  # French locale for European banking

class TransactionGenerator:
    """Generate realistic banking transactions"""
    
    TRANSACTION_TYPES = [
        'PAYMENT',          # Paiement par carte
        'TRANSFER',         # Virement
        'WITHDRAWAL',       # Retrait ATM
        'DEPOSIT',          # Dépôt
        'MOBILE_PAYMENT',   # Paiement mobile
        'DIRECT_DEBIT',     # Prélèvement automatique
        'CHECK',            # Chèque
        'ONLINE_PURCHASE'   # Achat en ligne
    ]
    
    TRANSACTION_STATUS = ['COMPLETED', 'PENDING', 'FAILED', 'CANCELLED']
    
    MERCHANT_CATEGORIES = [
        'Supermarket', 'Restaurant', 'Gas Station', 'Online Shop',
        'Pharmacy', 'Hotel', 'Airline', 'Electronics', 'Clothing',
        'Entertainment', 'Utilities', 'Insurance', 'Healthcare'
    ]
    
    def __init__(self, num_customers: int = 10000):
        self.num_customers = num_customers
        self.customers = self._generate_customers()
        self.merchants = self._generate_merchants()
        
    def _generate_customers(self) -> List[Dict]:
        """Generate customer master data"""
        logger.info(f"Generating {self.num_customers} customers...")
        customers = []
        
        for i in range(self.num_customers):
            customer = {
                'customer_id': f'CUST{i+1:08d}',
                'first_name': fake.first_name(),
                'last_name': fake.last_name(),
                'email': fake.email(),
                'phone': fake.phone_number(),
                'country': fake.country_code(),
                'city': fake.city(),
                'account_created': fake.date_between(start_date='-5y', end_date='today'),
                'account_type': random.choice(['STANDARD', 'PREMIUM', 'BUSINESS']),
                'risk_score': round(random.uniform(0, 100), 2)
            }
            customers.append(customer)
            
        return customers
    
    def _generate_merchants(self, num_merchants: int = 5000) -> List[Dict]:
        """Generate merchant master data"""
        logger.info(f"Generating {num_merchants} merchants...")
        merchants = []
        
        for i in range(num_merchants):
            category = random.choice(self.MERCHANT_CATEGORIES)
            merchant = {
                'merchant_id': f'MERCH{i+1:08d}',
                'merchant_name': fake.company(),
                'category': category,
                'country': fake.country_code(),
                'mcc_code': random.randint(1000, 9999)  # Merchant Category Code
            }
            merchants.append(merchant)
            
        return merchants
    
    def generate_transaction(self, transaction_date: datetime) -> Dict:
        """Generate a single realistic transaction"""
        
        transaction_type = random.choice(self.TRANSACTION_TYPES)
        customer = random.choice(self.customers)
        merchant = random.choice(self.merchants) if transaction_type in ['PAYMENT', 'ONLINE_PURCHASE'] else None
        
        # Amount distribution based on transaction type
        if transaction_type == 'WITHDRAWAL':
            amount = round(random.choice([20, 50, 100, 200, 500]), 2)
        elif transaction_type == 'TRANSFER':
            amount = round(random.uniform(100, 10000), 2)
        elif transaction_type == 'DEPOSIT':
            amount = round(random.uniform(500, 5000), 2)
        else:
            # Normal purchases - log-normal distribution for realism
            amount = round(abs(random.lognormvariate(3, 1.5)), 2)
        
        # Status distribution (95% success rate)
        status_weights = [0.95, 0.02, 0.02, 0.01]
        status = random.choices(self.TRANSACTION_STATUS, weights=status_weights)[0]
        
        # Add realistic timestamp within the day
        hour = int(random.triangular(6, 23, 12))  # Peak at noon
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        timestamp = transaction_date.replace(hour=hour, minute=minute, second=second)
        
        transaction = {
            'transaction_id': f'TXN{fake.uuid4().replace("-", "").upper()[:16]}',
            'transaction_date': transaction_date.strftime('%Y-%m-%d'),
            'transaction_timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            'customer_id': customer['customer_id'],
            'transaction_type': transaction_type,
            'amount': amount,
            'currency': 'EUR',
            'status': status,
            'merchant_id': merchant['merchant_id'] if merchant else None,
            'merchant_name': merchant['merchant_name'] if merchant else None,
            'merchant_category': merchant['category'] if merchant else None,
            'country': customer['country'],
            'channel': random.choice(['ONLINE', 'POS', 'ATM', 'MOBILE', 'BRANCH']),
            'card_type': random.choice(['DEBIT', 'CREDIT', None]),
            'is_fraudulent': random.random() < 0.001,  # 0.1% fraud rate
            'processing_time_ms': random.randint(50, 500) if status == 'COMPLETED' else random.randint(1000, 5000)
        }
        
        # Add some duplicates (data quality issue to clean in ETL)
        if random.random() < 0.0001:  # 0.01% duplicate rate
            transaction['_duplicate'] = True
        
        # Add some data quality issues
        if random.random() < 0.001:  # 0.1% missing data
            transaction['merchant_id'] = None
        
        return transaction
    
    def generate_transactions(
        self, 
        start_date: datetime, 
        end_date: datetime,
        transactions_per_day: int = 1000000
    ) -> List[Dict]:
        """Generate transactions for a date range"""
        
        logger.info(f"Generating transactions from {start_date} to {end_date}")
        logger.info(f"Target: {transactions_per_day:,} transactions per day")
        
        all_transactions = []
        current_date = start_date
        
        while current_date <= end_date:
            # Vary daily volume (weekends have less transactions)
            day_multiplier = 0.6 if current_date.weekday() >= 5 else 1.0
            daily_count = int(transactions_per_day * day_multiplier)
            
            logger.info(f"Generating {daily_count:,} transactions for {current_date.strftime('%Y-%m-%d')}")
            
            for _ in tqdm(range(daily_count), desc=f"Processing {current_date.strftime('%Y-%m-%d')}"):
                transaction = self.generate_transaction(current_date)
                all_transactions.append(transaction)
            
            current_date += timedelta(days=1)
        
        logger.info(f"Total transactions generated: {len(all_transactions):,}")
        return all_transactions
    
    def save_to_csv(self, transactions: List[Dict], output_path: Path):
        """Save transactions to CSV file"""
        
        logger.info(f"Saving transactions to {output_path}")
        
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        if transactions:
            fieldnames = transactions[0].keys()
            
            with open(output_path, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(transactions)
        
        logger.info(f"✓ Saved {len(transactions):,} transactions to {output_path}")
    
    def save_to_json(self, transactions: List[Dict], output_path: Path):
        """Save transactions to JSON file"""
        
        logger.info(f"Saving transactions to {output_path}")
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as jsonfile:
            json.dump(transactions, jsonfile, indent=2, default=str)
        
        logger.info(f"✓ Saved {len(transactions):,} transactions to {output_path}")
    
    def save_customers(self, output_path: Path):
        """Save customer dimension data"""
        
        logger.info(f"Saving {len(self.customers)} customers to {output_path}")
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', newline='', encoding='utf-8') as csvfile:
            if self.customers:
                writer = csv.DictWriter(csvfile, fieldnames=self.customers[0].keys())
                writer.writeheader()
                writer.writerows(self.customers)
        
        logger.info(f"✓ Customers saved to {output_path}")
    
    def save_merchants(self, output_path: Path):
        """Save merchant dimension data"""
        
        logger.info(f"Saving {len(self.merchants)} merchants to {output_path}")
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', newline='', encoding='utf-8') as csvfile:
            if self.merchants:
                writer = csv.DictWriter(csvfile, fieldnames=self.merchants[0].keys())
                writer.writeheader()
                writer.writerows(self.merchants)
        
        logger.info(f"✓ Merchants saved to {output_path}")


def main():
    parser = argparse.ArgumentParser(description='Generate banking transaction data')
    parser.add_argument('--count', type=int, default=1000000,
                       help='Number of transactions per day (default: 1,000,000)')
    parser.add_argument('--days', type=int, default=1,
                       help='Number of days to generate (default: 1)')
    parser.add_argument('--customers', type=int, default=10000,
                       help='Number of customers (default: 10,000)')
    parser.add_argument('--output', type=str, default='data/raw',
                       help='Output directory (default: data/raw)')
    parser.add_argument('--format', choices=['csv', 'json'], default='csv',
                       help='Output format (default: csv)')
    
    args = parser.parse_args()
    
    # Initialize generator
    generator = TransactionGenerator(num_customers=args.customers)
    
    # Generate date range
    end_date = datetime.now()
    start_date = end_date - timedelta(days=args.days - 1)
    
    # Generate transactions
    transactions = generator.generate_transactions(
        start_date=start_date,
        end_date=end_date,
        transactions_per_day=args.count
    )
    
    # Save transactions
    output_dir = Path(args.output)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    if args.format == 'csv':
        output_file = output_dir / f'transactions_{timestamp}.csv'
        generator.save_to_csv(transactions, output_file)
    else:
        output_file = output_dir / f'transactions_{timestamp}.json'
        generator.save_to_json(transactions, output_file)
    
    # Save dimension tables
    generator.save_customers(output_dir / f'customers_{timestamp}.csv')
    generator.save_merchants(output_dir / f'merchants_{timestamp}.csv')
    
    logger.info("=" * 60)
    logger.info("✓ Data generation completed successfully!")
    logger.info("=" * 60)
    logger.info(f"Transactions: {len(transactions):,}")
    logger.info(f"Customers: {len(generator.customers):,}")
    logger.info(f"Merchants: {len(generator.merchants):,}")
    logger.info(f"Output directory: {output_dir}")
    logger.info("=" * 60)


if __name__ == '__main__':
    main()

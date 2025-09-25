#!/usr/bin/env python3
"""
Data Synchronization System with Memory Caching and Persistence

This module implements a high-performance data synchronization system with:
- In-memory LRU caching
- Persistent daily JSON cache files
- Duplicate checking optimization
- Cache management and monitoring
"""

import json
import os
import sys
import time
import threading
import logging
from datetime import datetime, timedelta
from collections import OrderedDict
from typing import Dict, List, Optional, Set, Tuple, Any
from dataclasses import dataclass, asdict
import hashlib
import sqlite3
from pathlib import Path
import atexit
import signal
import psutil


@dataclass
class CacheRecord:
    """Represents a cached data record with business key components"""
    spin_position: str
    bucket_position: str
    start_date: str
    end_date: str
    lot_code: str
    main_line_id: str
    timestamp: float = None
    data: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = time.time()
    
    def get_business_key(self) -> str:
        """Generate unique business key from components"""
        key_components = [
            self.spin_position,
            self.bucket_position, 
            self.start_date,
            self.end_date,
            self.lot_code,
            self.main_line_id
        ]
        key_string = "|".join(str(comp) for comp in key_components)
        return hashlib.md5(key_string.encode()).hexdigest()


class CacheStatistics:
    """Cache performance statistics tracking"""
    
    def __init__(self):
        self.hits = 0
        self.misses = 0
        self.total_queries = 0
        self.db_queries = 0
        self.cache_size = 0
        self.start_time = time.time()
        self._lock = threading.Lock()
    
    def record_hit(self):
        with self._lock:
            self.hits += 1
            self.total_queries += 1
    
    def record_miss(self):
        with self._lock:
            self.misses += 1
            self.total_queries += 1
            self.db_queries += 1
    
    def update_cache_size(self, size: int):
        with self._lock:
            self.cache_size = size
    
    def get_hit_rate(self) -> float:
        with self._lock:
            if self.total_queries == 0:
                return 0.0
            return self.hits / self.total_queries
    
    def get_stats(self) -> Dict[str, Any]:
        with self._lock:
            uptime = time.time() - self.start_time
            return {
                'hits': self.hits,
                'misses': self.misses,
                'total_queries': self.total_queries,
                'db_queries': self.db_queries,
                'cache_size': self.cache_size,
                'hit_rate': self.get_hit_rate(),
                'uptime_seconds': uptime,
                'queries_per_second': self.total_queries / uptime if uptime > 0 else 0
            }


class LRUCache:
    """Thread-safe LRU cache implementation"""
    
    def __init__(self, max_size: int = 100000):
        self.max_size = max_size
        self._cache: OrderedDict[str, CacheRecord] = OrderedDict()
        self._lock = threading.RLock()
    
    def get(self, key: str) -> Optional[CacheRecord]:
        with self._lock:
            if key in self._cache:
                # Move to end (most recently used)
                record = self._cache.pop(key)
                self._cache[key] = record
                return record
            return None
    
    def put(self, key: str, record: CacheRecord):
        with self._lock:
            if key in self._cache:
                # Update existing record
                self._cache.pop(key)
            elif len(self._cache) >= self.max_size:
                # Remove least recently used item
                self._cache.popitem(last=False)
            
            self._cache[key] = record
    
    def remove(self, key: str) -> bool:
        with self._lock:
            if key in self._cache:
                del self._cache[key]
                return True
            return False
    
    def size(self) -> int:
        with self._lock:
            return len(self._cache)
    
    def keys(self) -> List[str]:
        with self._lock:
            return list(self._cache.keys())
    
    def clear(self):
        with self._lock:
            self._cache.clear()
    
    def get_all_records(self) -> Dict[str, Dict]:
        """Get all cached records for persistence"""
        with self._lock:
            return {key: asdict(record) for key, record in self._cache.items()}


class DataSyncSystem:
    """Main data synchronization system with caching and persistence"""
    
    def __init__(self, config: Dict[str, Any] = None):
        self.config = self._load_config(config)
        self.cache = LRUCache(self.config['max_cache_size'])
        self.stats = CacheStatistics()
        self.cache_dir = Path(self.config['cache_directory'])
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        # Setup logging
        self._setup_logging()
        
        # Database connection (placeholder - would connect to actual DB)
        self.db_connection = None
        self._init_database()
        
        # Load recent cache files on startup
        self._load_recent_caches()
        
        # Register cleanup handlers
        atexit.register(self._cleanup)
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        
        # Start background maintenance thread (optional for testing)
        if not config or config.get('enable_maintenance_thread', True):
            self._start_maintenance_thread()
        
        self.logger.info("Data synchronization system initialized")
    
    def _load_config(self, config: Dict[str, Any] = None) -> Dict[str, Any]:
        """Load configuration with defaults"""
        defaults = {
            'max_cache_size': 100000,
            'cache_directory': './cache',
            'cache_retention_days': 7,
            'auto_save_interval': 300,  # 5 minutes
            'cleanup_interval': 3600,   # 1 hour
            'load_recent_days': 3,
            'log_level': 'INFO',
            'log_file': 'data_sync.log'
        }
        
        if config:
            defaults.update(config)
        
        return defaults
    
    def _setup_logging(self):
        """Setup logging configuration"""
        logging.basicConfig(
            level=getattr(logging, self.config['log_level']),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.config['log_file']),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger('DataSyncSystem')
    
    def _init_database(self):
        """Initialize database connection (placeholder)"""
        # This would connect to actual database in real implementation
        # For demo purposes, using SQLite
        try:
            db_path = self.cache_dir / 'demo.db'
            
            # Remove existing database for clean start in testing
            if db_path.exists() and self.config.get('clean_database', False):
                db_path.unlink()
            
            self.db_connection = sqlite3.connect(str(db_path), check_same_thread=False)
            self.db_connection.execute('PRAGMA journal_mode=WAL')  # Better concurrency
            
            # Create demo table
            cursor = self.db_connection.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS records (
                    business_key TEXT PRIMARY KEY,
                    spin_position TEXT,
                    bucket_position TEXT,
                    start_date TEXT,
                    end_date TEXT,
                    lot_code TEXT,
                    main_line_id TEXT,
                    data TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            # Create index for better query performance
            cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_records_business_key 
                ON records(business_key)
            ''')
            self.db_connection.commit()
            
        except Exception as e:
            self.logger.error(f"Error initializing database: {e}")
            raise
    
    def _load_recent_caches(self):
        """Load recent cache files on startup"""
        try:
            load_days = self.config['load_recent_days']
            loaded_count = 0
            
            for i in range(load_days):
                date = datetime.now() - timedelta(days=i)
                cache_file = self._get_cache_filename(date)
                
                if cache_file.exists():
                    records_loaded = self._load_cache_file(cache_file)
                    loaded_count += records_loaded
                    self.logger.info(f"Loaded {records_loaded} records from {cache_file}")
            
            self.logger.info(f"Total loaded {loaded_count} records from recent cache files")
            
        except Exception as e:
            self.logger.error(f"Error loading recent caches: {e}")
    
    def _load_cache_file(self, cache_file: Path) -> int:
        """Load records from a cache file"""
        try:
            with open(cache_file, 'r') as f:
                data = json.load(f)
            
            loaded_count = 0
            for key, record_data in data.get('records', {}).items():
                try:
                    # Ensure timestamp is set if missing
                    if 'timestamp' not in record_data or record_data['timestamp'] is None:
                        record_data['timestamp'] = time.time()
                    record = CacheRecord(**record_data)
                    self.cache.put(key, record)
                    loaded_count += 1
                except Exception as e:
                    self.logger.warning(f"Error loading record {key}: {e}")
            
            return loaded_count
            
        except Exception as e:
            self.logger.error(f"Error loading cache file {cache_file}: {e}")
            return 0
    
    def _get_cache_filename(self, date: datetime) -> Path:
        """Generate cache filename for given date"""
        date_str = date.strftime('%Y-%m-%d')
        return self.cache_dir / f"cache_{date_str}.json"
    
    def _start_maintenance_thread(self):
        """Start background maintenance thread"""
        def maintenance_loop():
            while True:
                try:
                    # Auto-save cache
                    self.save_cache()
                    
                    # Clean up old cache files
                    self._cleanup_old_cache_files()
                    
                    # Update statistics
                    self.stats.update_cache_size(self.cache.size())
                    
                    # Log statistics periodically
                    stats = self.stats.get_stats()
                    self.logger.info(f"Cache stats: {stats}")
                    
                    time.sleep(self.config['cleanup_interval'])
                    
                except Exception as e:
                    self.logger.error(f"Error in maintenance thread: {e}")
                    time.sleep(60)  # Wait a bit before retrying
        
        maintenance_thread = threading.Thread(target=maintenance_loop, daemon=True)
        maintenance_thread.start()
        self.logger.info("Background maintenance thread started")
    
    def _cleanup_old_cache_files(self):
        """Remove cache files older than retention period"""
        try:
            cutoff_date = datetime.now() - timedelta(days=self.config['cache_retention_days'])
            removed_count = 0
            
            for cache_file in self.cache_dir.glob('cache_*.json'):
                try:
                    # Extract date from filename
                    date_str = cache_file.stem.replace('cache_', '')
                    file_date = datetime.strptime(date_str, '%Y-%m-%d')
                    
                    if file_date < cutoff_date:
                        cache_file.unlink()
                        removed_count += 1
                        self.logger.info(f"Removed old cache file: {cache_file}")
                        
                except Exception as e:
                    self.logger.warning(f"Error processing cache file {cache_file}: {e}")
            
            if removed_count > 0:
                self.logger.info(f"Cleaned up {removed_count} old cache files")
                
        except Exception as e:
            self.logger.error(f"Error during cache cleanup: {e}")
    
    def check_record_exists(self, record: CacheRecord) -> bool:
        """Check if record exists with duplicate check optimization"""
        business_key = record.get_business_key()
        
        # First check memory cache
        cached_record = self.cache.get(business_key)
        if cached_record is not None:
            self.stats.record_hit()
            self.logger.debug(f"Cache hit for key: {business_key}")
            return True
        
        # Cache miss - check database
        self.stats.record_miss()
        self.logger.debug(f"Cache miss for key: {business_key}")
        
        exists = self._check_database(business_key)
        
        if exists:
            # Add to cache for future queries
            self.cache.put(business_key, record)
        
        return exists
    
    def _check_database(self, business_key: str) -> bool:
        """Check if record exists in database"""
        try:
            with self.db_connection:  # Use context manager for transaction
                cursor = self.db_connection.cursor()
                cursor.execute('SELECT 1 FROM records WHERE business_key = ? LIMIT 1', (business_key,))
                result = cursor.fetchone()
                return result is not None
                
        except Exception as e:
            self.logger.error(f"Database query error: {e}")
            return False
    
    def insert_record(self, record: CacheRecord) -> bool:
        """Insert new record with caching"""
        try:
            business_key = record.get_business_key()
            
            # Insert into database
            with self.db_connection:  # Use context manager for transaction
                cursor = self.db_connection.cursor()
                cursor.execute('''
                    INSERT OR REPLACE INTO records 
                    (business_key, spin_position, bucket_position, start_date, 
                     end_date, lot_code, main_line_id, data)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    business_key,
                    record.spin_position,
                    record.bucket_position,
                    record.start_date,
                    record.end_date,
                    record.lot_code,
                    record.main_line_id,
                    json.dumps(record.data) if record.data else None
                ))
            
            # Update cache
            if record.timestamp is None:
                record.timestamp = time.time()
            self.cache.put(business_key, record)
            
            self.logger.debug(f"Inserted record with key: {business_key}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error inserting record: {e}")
            return False
    
    def save_cache(self) -> bool:
        """Save current cache to daily JSON file"""
        try:
            cache_file = self._get_cache_filename(datetime.now())
            
            # Ensure cache directory exists
            cache_file.parent.mkdir(parents=True, exist_ok=True)
            
            cache_data = {
                'timestamp': datetime.now().isoformat(),
                'cache_size': self.cache.size(),
                'records': self.cache.get_all_records()
            }
            
            # Write to temporary file first, then rename for atomicity
            temp_file = cache_file.with_suffix('.tmp')
            with open(temp_file, 'w') as f:
                json.dump(cache_data, f, indent=2)
            
            temp_file.rename(cache_file)
            
            self.logger.info(f"Saved cache to {cache_file} ({self.cache.size()} records)")
            return True
            
        except Exception as e:
            self.logger.error(f"Error saving cache: {e}")
            return False
    
    def get_cache_statistics(self) -> Dict[str, Any]:
        """Get current cache statistics"""
        stats = self.stats.get_stats()
        
        # Add memory usage information
        try:
            import psutil
            process = psutil.Process()
            memory_info = process.memory_info()
            stats['memory_usage_mb'] = memory_info.rss / 1024 / 1024
            stats['memory_percent'] = process.memory_percent()
        except ImportError:
            # psutil not available
            pass
        except Exception:
            # Other psutil errors
            pass
        
        return stats
    
    def get_system_status(self) -> Dict[str, Any]:
        """Get comprehensive system status"""
        return {
            'cache_statistics': self.get_cache_statistics(),
            'configuration': self.config,
            'cache_files': [f.name for f in self.cache_dir.glob('cache_*.json')],
            'system_info': {
                'python_version': sys.version,
                'cache_directory': str(self.cache_dir),
                'uptime': time.time() - self.stats.start_time
            }
        }
    
    def _signal_handler(self, signum, frame):
        """Handle termination signals"""
        self.logger.info(f"Received signal {signum}, initiating graceful shutdown")
        self._cleanup()
        sys.exit(0)
    
    def _cleanup(self):
        """Cleanup resources and save state"""
        try:
            self.logger.info("Performing cleanup...")
            
            # Save current cache
            self.save_cache()
            
            # Close database connection
            if self.db_connection:
                self.db_connection.close()
                
            self.logger.info("Cleanup completed")
            
        except Exception as e:
            self.logger.error(f"Error during cleanup: {e}")


def main():
    """Example usage of the data synchronization system"""
    # Configuration
    config = {
        'max_cache_size': 50000,
        'cache_directory': './cache_data',
        'cache_retention_days': 7,
        'log_level': 'INFO'
    }
    
    # Initialize system
    sync_system = DataSyncSystem(config)
    
    # Example usage
    print("Data Synchronization System Demo")
    print("=" * 40)
    
    # Create some sample records
    sample_records = [
        CacheRecord(
            spin_position="SP001",
            bucket_position="BP001", 
            start_date="2024-01-01",
            end_date="2024-01-02",
            lot_code="LOT001",
            main_line_id="ML001",
            data={"temperature": 25.5, "pressure": 1013.25}
        ),
        CacheRecord(
            spin_position="SP002",
            bucket_position="BP002",
            start_date="2024-01-02", 
            end_date="2024-01-03",
            lot_code="LOT002",
            main_line_id="ML002",
            data={"temperature": 26.0, "pressure": 1012.80}
        )
    ]
    
    # Test the system
    for record in sample_records:
        print(f"\nTesting record: {record.get_business_key()[:8]}...")
        
        # First check (should be cache miss)
        exists = sync_system.check_record_exists(record)
        print(f"First check - exists: {exists}")
        
        # Insert record
        if not exists:
            success = sync_system.insert_record(record)
            print(f"Insert result: {success}")
        
        # Second check (should be cache hit)
        exists = sync_system.check_record_exists(record)
        print(f"Second check - exists: {exists}")
    
    # Show statistics
    print(f"\nCache Statistics:")
    stats = sync_system.get_cache_statistics()
    for key, value in stats.items():
        print(f"  {key}: {value}")
    
    # Save cache manually
    sync_system.save_cache()
    print(f"\nCache saved to file")
    
    print(f"\nDemo completed. System will continue running...")
    
    # Keep running for demonstration
    try:
        while True:
            time.sleep(10)
            stats = sync_system.get_cache_statistics()
            print(f"Hit rate: {stats['hit_rate']:.2%}, Cache size: {stats['cache_size']}")
    except KeyboardInterrupt:
        print("\nShutting down...")


if __name__ == "__main__":
    main()
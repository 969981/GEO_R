#!/usr/bin/env python3
"""
Simple test script for the data synchronization system
"""

import time
import sys
from pathlib import Path

# Add current directory to path
sys.path.append('.')

from data_sync_system import DataSyncSystem, CacheRecord


def test_basic_functionality():
    """Test basic cache functionality"""
    print("Testing basic data synchronization functionality...")
    
    # Configuration for testing
    config = {
        'max_cache_size': 1000,
        'cache_directory': './test_cache',
        'cache_retention_days': 1,
        'auto_save_interval': 60,
        'cleanup_interval': 3600,
        'load_recent_days': 1,
        'log_level': 'INFO',
        'enable_maintenance_thread': False,  # Disable for testing
        'clean_database': True  # Start with clean database
    }
    
    # Initialize system
    sync_system = DataSyncSystem(config)
    
    print("✓ System initialized successfully")
    
    # Create test records
    test_records = []
    for i in range(5):
        record = CacheRecord(
            spin_position=f"SP{i:03d}",
            bucket_position=f"BP{i:03d}",
            start_date="2024-01-01",
            end_date="2024-01-02",
            lot_code=f"LOT{i:03d}",
            main_line_id=f"ML{i:03d}",
            data={"test": True, "value": i}
        )
        test_records.append(record)
    
    print(f"✓ Created {len(test_records)} test records")
    
    # Test cache operations
    results = {
        'first_checks': [],
        'inserts': [],
        'second_checks': []
    }
    
    for i, record in enumerate(test_records):
        # First check (should be cache miss)
        exists = sync_system.check_record_exists(record)
        results['first_checks'].append(exists)
        
        # Insert record
        if not exists:
            success = sync_system.insert_record(record)
            results['inserts'].append(success)
        else:
            results['inserts'].append(None)
        
        # Second check (should be cache hit)
        exists = sync_system.check_record_exists(record)
        results['second_checks'].append(exists)
        
        print(f"  Record {i}: First check={results['first_checks'][i]}, "
              f"Insert={results['inserts'][i]}, Second check={results['second_checks'][i]}")
    
    # Get statistics
    stats = sync_system.get_cache_statistics()
    print(f"\n📊 Performance Statistics:")
    print(f"  Cache Hit Rate:     {stats['hit_rate']:.2%}")
    print(f"  Total Queries:      {stats['total_queries']}")
    print(f"  Cache Hits:         {stats['hits']}")
    print(f"  Cache Misses:       {stats['misses']}")
    print(f"  Database Queries:   {stats['db_queries']}")
    print(f"  Cache Size:         {stats['cache_size']}")
    
    # Test cache persistence
    print(f"\n💾 Testing cache persistence...")
    success = sync_system.save_cache()
    print(f"  Cache save: {'✓' if success else '✗'}")
    
    # Verify cache file exists
    cache_files = list(Path(config['cache_directory']).glob('cache_*.json'))
    print(f"  Cache files found: {len(cache_files)}")
    
    # Clean up
    sync_system._cleanup()
    print(f"✓ System cleanup completed")
    
    return stats


def test_performance():
    """Test performance with more records"""
    print(f"\n🚀 Performance Test")
    print("="*40)
    
    config = {
        'max_cache_size': 10000,
        'cache_directory': './perf_cache',
        'log_level': 'WARNING',  # Reduce log noise
        'enable_maintenance_thread': False,  # Disable for testing
        'clean_database': True  # Start with clean database
    }
    
    sync_system = DataSyncSystem(config)
    
    # Create test records
    num_records = 100
    test_records = []
    for i in range(num_records):
        record = CacheRecord(
            spin_position=f"SP{i:04d}",
            bucket_position=f"BP{i:04d}",
            start_date="2024-01-01",
            end_date="2024-01-02",
            lot_code=f"LOT{i:04d}",
            main_line_id=f"ML{i:04d}",
            data={"performance_test": True, "index": i}
        )
        test_records.append(record)
    
    print(f"Created {num_records} test records")
    
    # Measure insertion performance
    start_time = time.time()
    
    for record in test_records:
        exists = sync_system.check_record_exists(record)
        if not exists:
            sync_system.insert_record(record)
    
    insert_duration = time.time() - start_time
    
    # Measure lookup performance (all should be cache hits)
    start_time = time.time()
    
    for record in test_records:
        sync_system.check_record_exists(record)
    
    lookup_duration = time.time() - start_time
    
    stats = sync_system.get_cache_statistics()
    
    print(f"\n📈 Performance Results:")
    print(f"  Records processed:    {num_records}")
    print(f"  Insert time:          {insert_duration:.3f} seconds")
    print(f"  Lookup time:          {lookup_duration:.3f} seconds")
    print(f"  Inserts/second:       {num_records / insert_duration:.1f}")
    print(f"  Lookups/second:       {num_records / lookup_duration:.1f}")
    print(f"  Cache hit rate:       {stats['hit_rate']:.2%}")
    print(f"  Total queries:        {stats['total_queries']}")
    print(f"  Database queries:     {stats['db_queries']}")
    
    # Clean up
    sync_system._cleanup()
    
    return stats


def main():
    """Run all tests"""
    print("="*60)
    print("     DATA SYNCHRONIZATION SYSTEM TESTS")
    print("="*60)
    
    try:
        # Basic functionality test
        basic_stats = test_basic_functionality()
        
        # Performance test
        perf_stats = test_performance()
        
        print(f"\n✅ All tests completed successfully!")
        print(f"\nSummary:")
        print(f"  Basic test hit rate:  {basic_stats['hit_rate']:.2%}")
        print(f"  Perf test hit rate:   {perf_stats['hit_rate']:.2%}")
        
        # Clean up test directories
        import shutil
        for test_dir in ['./test_cache', './perf_cache']:
            if Path(test_dir).exists():
                shutil.rmtree(test_dir)
        print(f"  Test directories cleaned up")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
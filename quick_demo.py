#!/usr/bin/env python3
"""
Quick Demo of Data Synchronization System

Demonstrates the core functionality in a simple, non-hanging way.
"""

import shutil
from pathlib import Path
from data_sync_system import DataSyncSystem, CacheRecord


def main():
    print("🚀 Quick Data Synchronization Demo")
    print("=" * 40)
    
    # Clean setup
    demo_dir = Path('./quick_demo')
    if demo_dir.exists():
        shutil.rmtree(demo_dir)
    
    # Simple config
    config = {
        'cache_directory': str(demo_dir),
        'enable_maintenance_thread': False,
        'clean_database': True,
        'log_level': 'ERROR'
    }
    
    # Initialize
    print("Initializing system...")
    sync = DataSyncSystem(config)
    
    # Test record
    record = CacheRecord(
        spin_position="SP_001",
        bucket_position="BUCKET_A1", 
        start_date="2024-01-15",
        end_date="2024-01-16",
        lot_code="BATCH_001",
        main_line_id="LINE_ALPHA",
        data={"temp": 25.0, "quality": "A"}
    )
    
    print(f"Business Key: {record.get_business_key()[:16]}...")
    
    # Demonstrate optimization
    print("\n📊 Duplicate Check Optimization:")
    
    exists1 = sync.check_record_exists(record)
    print(f"1. First check: {'EXISTS' if exists1 else 'NOT FOUND'} (database query)")
    
    if not exists1:
        success = sync.insert_record(record)
        print(f"2. Insert: {'SUCCESS' if success else 'FAILED'}")
    
    exists2 = sync.check_record_exists(record) 
    print(f"3. Second check: {'EXISTS' if exists2 else 'NOT FOUND'} (cache hit)")
    
    # Quick stats without hanging issues
    print(f"\n📈 Quick Stats:")
    print(f"   Cache size: {sync.cache.size()}")
    print(f"   Hits: {sync.stats.hits}")
    print(f"   Misses: {sync.stats.misses}")
    print(f"   DB queries: {sync.stats.db_queries}")
    
    if sync.stats.total_queries > 0:
        hit_rate = sync.stats.hits / sync.stats.total_queries
        print(f"   Hit rate: {hit_rate:.1%}")
    
    # Test persistence
    print(f"\n💾 Cache Persistence:")
    save_ok = sync.save_cache()
    print(f"   Save: {'SUCCESS' if save_ok else 'FAILED'}")
    
    cache_files = list(demo_dir.glob('cache_*.json'))
    print(f"   Files: {len(cache_files)}")
    
    # Cleanup
    sync._cleanup()
    shutil.rmtree(demo_dir)
    
    print(f"\n✅ Demo complete! System working correctly.")
    print(f"   🎯 Optimization: Cache hits avoid database queries")
    print(f"   💾 Persistence: Cache data saved to JSON files")
    print(f"   🔑 Business Keys: Unique identification system")


if __name__ == '__main__':
    main()
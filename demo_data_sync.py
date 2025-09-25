#!/usr/bin/env python3
"""
Data Synchronization System Demo

This demo shows the core functionality of the data synchronization system:
- Memory caching with LRU eviction
- Database persistence
- Duplicate checking optimization
- Cache statistics
"""

import shutil
import json
from pathlib import Path
from data_sync_system import DataSyncSystem, CacheRecord


def demo_basic_operations():
    """Demonstrate basic cache operations"""
    print("🚀 Data Synchronization System Demo")
    print("=" * 50)
    
    # Clean setup
    demo_dir = Path('./demo_cache')
    if demo_dir.exists():
        shutil.rmtree(demo_dir)
    
    # Configuration
    config = {
        'cache_directory': './demo_cache',
        'max_cache_size': 1000,
        'enable_maintenance_thread': False,  # Disable for demo stability
        'clean_database': True,
        'log_level': 'WARNING'
    }
    
    # Initialize system
    print("📦 Initializing data synchronization system...")
    sync_system = DataSyncSystem(config)
    print("✅ System initialized!")
    
    # Create sample records with business keys
    sample_records = [
        CacheRecord(
            spin_position="LINE_A_SP_001",
            bucket_position="BUCKET_ZONE_1", 
            start_date="2024-01-15",
            end_date="2024-01-16",
            lot_code="BATCH_2024_001",
            main_line_id="MAIN_LINE_ALPHA",
            data={"temperature": 23.5, "humidity": 65, "quality": "A"}
        ),
        CacheRecord(
            spin_position="LINE_B_SP_002",
            bucket_position="BUCKET_ZONE_2",
            start_date="2024-01-15", 
            end_date="2024-01-16",
            lot_code="BATCH_2024_002",
            main_line_id="MAIN_LINE_BETA",
            data={"temperature": 24.1, "humidity": 62, "quality": "A+"}
        ),
        CacheRecord(
            spin_position="LINE_C_SP_003",
            bucket_position="BUCKET_ZONE_1",
            start_date="2024-01-16",
            end_date="2024-01-17", 
            lot_code="BATCH_2024_003",
            main_line_id="MAIN_LINE_GAMMA",
            data={"temperature": 22.8, "humidity": 68, "quality": "B"}
        )
    ]
    
    print(f"\n📋 Processing {len(sample_records)} sample records...")
    
    # Demonstrate the optimization: first check (cache miss) -> insert -> second check (cache hit)
    results = []
    for i, record in enumerate(sample_records):
        print(f"\n🔍 Record {i+1}: {record.lot_code}")
        
        # Generate business key for display
        business_key = record.get_business_key()
        print(f"   Business Key: {business_key[:16]}...")
        
        # First check - should be cache miss
        exists_1 = sync_system.check_record_exists(record)
        print(f"   First check (cache): {'EXISTS' if exists_1 else 'NOT FOUND'}")
        
        # Insert if not exists
        if not exists_1:
            success = sync_system.insert_record(record)
            print(f"   Insert operation: {'SUCCESS' if success else 'FAILED'}")
        
        # Second check - should be cache hit
        exists_2 = sync_system.check_record_exists(record)
        print(f"   Second check (cache): {'EXISTS' if exists_2 else 'NOT FOUND'}")
        
        results.append({
            'record': i+1,
            'first_check': exists_1,
            'insert_success': not exists_1,
            'second_check': exists_2,
            'business_key': business_key
        })
    
    # Show performance statistics
    print(f"\n📊 Performance Statistics:")
    stats = sync_system.stats.get_stats()
    print(f"   Cache Hit Rate:     {stats['hit_rate']:.1%}")
    print(f"   Total Queries:      {stats['total_queries']}")
    print(f"   Cache Hits:         {stats['hits']}")
    print(f"   Cache Misses:       {stats['misses']}")
    print(f"   Database Queries:   {stats['db_queries']}")
    print(f"   Current Cache Size: {stats['cache_size']}")
    
    # Demonstrate persistence
    print(f"\n💾 Testing cache persistence...")
    save_success = sync_system.save_cache()
    print(f"   Cache save: {'✅ SUCCESS' if save_success else '❌ FAILED'}")
    
    # Show cache files
    cache_files = list(demo_dir.glob('cache_*.json'))
    print(f"   Cache files created: {len(cache_files)}")
    for cache_file in cache_files:
        size = cache_file.stat().st_size
        print(f"   • {cache_file.name} ({size:,} bytes)")
    
    # Demonstrate cache content
    if cache_files:
        print(f"\n📄 Cache file content preview:")
        with open(cache_files[0], 'r') as f:
            cache_data = json.load(f)
        print(f"   Timestamp: {cache_data['timestamp']}")
        print(f"   Records stored: {cache_data['cache_size']}")
        print(f"   Sample keys: {list(cache_data['records'].keys())[:2]}")
    
    # Test repeat access (should be all cache hits)
    print(f"\n🔄 Testing repeat access (should be cache hits)...")
    for i, record in enumerate(sample_records):
        exists = sync_system.check_record_exists(record)
        print(f"   Record {i+1}: {'✅ FOUND' if exists else '❌ NOT FOUND'}")
    
    # Final statistics
    print(f"\n📈 Final Performance Statistics:")
    final_stats = sync_system.stats.get_stats()
    print(f"   Cache Hit Rate:     {final_stats['hit_rate']:.1%}")
    print(f"   Total Queries:      {final_stats['total_queries']}")
    print(f"   Database Queries:   {final_stats['db_queries']}")
    print(f"   Efficiency Gain:    {((final_stats['total_queries'] - final_stats['db_queries']) / final_stats['total_queries']):.1%}")
    
    # Cleanup
    sync_system._cleanup()
    print(f"\n🧹 Demo completed! Cache saved and system cleaned up.")
    
    return final_stats


def demo_performance_test():
    """Demonstrate performance with larger dataset"""
    print(f"\n⚡ Performance Test with Larger Dataset")
    print("=" * 50)
    
    # Clean setup
    perf_dir = Path('./perf_demo')
    if perf_dir.exists():
        shutil.rmtree(perf_dir)
    
    config = {
        'cache_directory': './perf_demo',
        'max_cache_size': 5000,
        'enable_maintenance_thread': False,
        'clean_database': True, 
        'log_level': 'ERROR'  # Minimal logging for performance
    }
    
    sync_system = DataSyncSystem(config)
    
    # Generate test records
    import time
    num_records = 50
    test_records = []
    
    print(f"📝 Generating {num_records} test records...")
    for i in range(num_records):
        record = CacheRecord(
            spin_position=f"LINE_{chr(65 + (i % 5))}_SP_{i:04d}",
            bucket_position=f"ZONE_{(i % 3) + 1}_BUCKET_{i:04d}",
            start_date=f"2024-01-{(i % 28) + 1:02d}",
            end_date=f"2024-01-{((i % 28) + 2):02d}",
            lot_code=f"BATCH_2024_{i:04d}",
            main_line_id=f"MAIN_LINE_{chr(65 + (i % 3))}",
            data={"value": i, "test": True}
        )
        test_records.append(record)
    
    # Time the insertion phase
    print(f"⏱️  Timing insertion phase...")
    start_time = time.time()
    
    for record in test_records:
        exists = sync_system.check_record_exists(record)
        if not exists:
            sync_system.insert_record(record)
    
    insert_time = time.time() - start_time
    
    # Time the lookup phase (should be all cache hits)
    print(f"⏱️  Timing lookup phase...")
    start_time = time.time()
    
    for record in test_records:
        sync_system.check_record_exists(record)
    
    lookup_time = time.time() - start_time
    
    # Results
    stats = sync_system.stats.get_stats()
    print(f"\n📊 Performance Results:")
    print(f"   Records Processed:   {num_records}")
    print(f"   Insert Time:         {insert_time:.3f} seconds")
    print(f"   Lookup Time:         {lookup_time:.3f} seconds")
    print(f"   Insert Rate:         {num_records / insert_time:.1f} records/sec")
    print(f"   Lookup Rate:         {num_records / lookup_time:.1f} records/sec")
    print(f"   Cache Hit Rate:      {stats['hit_rate']:.1%}")
    print(f"   Total Queries:       {stats['total_queries']}")
    print(f"   Database Queries:    {stats['db_queries']}")
    print(f"   Performance Boost:   {stats['total_queries'] / max(stats['db_queries'], 1):.1f}x")
    
    sync_system._cleanup()
    return stats


def main():
    """Run the complete demo"""
    try:
        # Basic operations demo
        basic_stats = demo_basic_operations()
        
        # Performance test demo
        perf_stats = demo_performance_test()
        
        print(f"\n🎉 Demo Summary")
        print("=" * 50)
        print(f"✅ All demos completed successfully!")
        print(f"📈 Basic demo hit rate:  {basic_stats['hit_rate']:.1%}")
        print(f"🚀 Performance hit rate: {perf_stats['hit_rate']:.1%}")
        print(f"💡 Database query reduction: {((perf_stats['total_queries'] - perf_stats['db_queries']) / perf_stats['total_queries']):.1%}")
        
        # Cleanup demo directories
        for demo_dir in ['./demo_cache', './perf_demo']:
            if Path(demo_dir).exists():
                shutil.rmtree(demo_dir)
        print(f"🧹 Demo directories cleaned up")
        
    except Exception as e:
        print(f"❌ Demo failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()
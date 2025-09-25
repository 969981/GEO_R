#!/usr/bin/env python3
"""
Command Line Interface for Data Synchronization System

Provides command-line tools for managing the data sync system:
- Start/stop the sync system
- Monitor cache statistics
- Manage cache files
- Configuration management
"""

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Dict, Any
import subprocess

from data_sync_system import DataSyncSystem, CacheRecord


class SyncCLI:
    """Command line interface for data synchronization system"""
    
    def __init__(self):
        self.config_file = Path('sync_config.json')
        self.config = self._load_config()
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from JSON file"""
        try:
            if self.config_file.exists():
                with open(self.config_file, 'r') as f:
                    return json.load(f)
            else:
                print(f"Warning: Config file {self.config_file} not found, using defaults")
                return {}
        except Exception as e:
            print(f"Error loading config: {e}")
            return {}
    
    def start_system(self, args):
        """Start the data synchronization system"""
        print("Starting Data Synchronization System...")
        
        config = self.config.get('data_sync_system', {})
        if args.cache_size:
            config['max_cache_size'] = args.cache_size
        if args.cache_dir:
            config['cache_directory'] = args.cache_dir
        if args.retention_days:
            config['cache_retention_days'] = args.retention_days
        
        try:
            sync_system = DataSyncSystem(config)
            print("System started successfully!")
            
            if args.daemon:
                print("Running in daemon mode...")
                while True:
                    time.sleep(60)
                    stats = sync_system.get_cache_statistics()
                    if args.verbose:
                        print(f"Stats: Hit rate: {stats['hit_rate']:.2%}, "
                              f"Cache size: {stats['cache_size']}, "
                              f"Memory: {stats.get('memory_usage_mb', 'N/A')} MB")
            else:
                print("System running. Press Ctrl+C to stop...")
                try:
                    while True:
                        time.sleep(1)
                except KeyboardInterrupt:
                    print("\nShutting down...")
                    
        except Exception as e:
            print(f"Error starting system: {e}")
            sys.exit(1)
    
    def show_stats(self, args):
        """Show current cache statistics"""
        try:
            config = self.config.get('data_sync_system', {})
            sync_system = DataSyncSystem(config)
            
            if args.json:
                stats = sync_system.get_cache_statistics()
                print(json.dumps(stats, indent=2))
            else:
                self._print_stats_table(sync_system.get_cache_statistics())
                
        except Exception as e:
            print(f"Error getting statistics: {e}")
            sys.exit(1)
    
    def _print_stats_table(self, stats: Dict[str, Any]):
        """Print statistics in a formatted table"""
        print("\n" + "="*50)
        print("   DATA SYNCHRONIZATION SYSTEM STATISTICS")
        print("="*50)
        
        print(f"Cache Hit Rate:      {stats['hit_rate']:.2%}")
        print(f"Total Queries:       {stats['total_queries']:,}")
        print(f"Cache Hits:          {stats['hits']:,}")
        print(f"Cache Misses:        {stats['misses']:,}")
        print(f"Database Queries:    {stats['db_queries']:,}")
        print(f"Cache Size:          {stats['cache_size']:,}")
        print(f"Uptime:              {stats['uptime_seconds']:.1f} seconds")
        print(f"Queries/Second:      {stats['queries_per_second']:.2f}")
        
        if 'memory_usage_mb' in stats:
            print(f"Memory Usage:        {stats['memory_usage_mb']:.1f} MB")
            print(f"Memory Percent:      {stats['memory_percent']:.1f}%")
        
        print("="*50)
    
    def show_status(self, args):
        """Show comprehensive system status"""
        try:
            config = self.config.get('data_sync_system', {})
            sync_system = DataSyncSystem(config)
            
            status = sync_system.get_system_status()
            
            if args.json:
                print(json.dumps(status, indent=2, default=str))
            else:
                self._print_status(status)
                
        except Exception as e:
            print(f"Error getting status: {e}")
            sys.exit(1)
    
    def _print_status(self, status: Dict[str, Any]):
        """Print system status in formatted output"""
        print("\n" + "="*60)
        print("        DATA SYNCHRONIZATION SYSTEM STATUS")
        print("="*60)
        
        # Cache Statistics
        print("\n📊 CACHE STATISTICS:")
        stats = status['cache_statistics']
        print(f"  Hit Rate:           {stats['hit_rate']:.2%}")
        print(f"  Cache Size:         {stats['cache_size']:,}")
        print(f"  Total Queries:      {stats['total_queries']:,}")
        print(f"  Database Queries:   {stats['db_queries']:,}")
        
        # Configuration
        print("\n⚙️  CONFIGURATION:")
        config = status['configuration']
        print(f"  Max Cache Size:     {config['max_cache_size']:,}")
        print(f"  Cache Directory:    {config['cache_directory']}")
        print(f"  Retention Days:     {config['cache_retention_days']}")
        print(f"  Log Level:          {config['log_level']}")
        
        # Cache Files
        print("\n📁 CACHE FILES:")
        cache_files = status['cache_files']
        if cache_files:
            for file in sorted(cache_files):
                print(f"  • {file}")
        else:
            print("  No cache files found")
        
        # System Info
        print("\n🖥️  SYSTEM INFO:")
        sys_info = status['system_info']
        print(f"  Python Version:     {sys_info['python_version'].split()[0]}")
        print(f"  Cache Directory:    {sys_info['cache_directory']}")
        print(f"  Uptime:             {sys_info['uptime']:.1f} seconds")
        
        print("="*60)
    
    def manage_cache(self, args):
        """Manage cache files"""
        config = self.config.get('data_sync_system', {})
        cache_dir = Path(config.get('cache_directory', './cache_data'))
        
        if args.action == 'list':
            self._list_cache_files(cache_dir)
        elif args.action == 'clean':
            self._clean_cache_files(cache_dir, args.days)
        elif args.action == 'save':
            self._save_cache(config)
        elif args.action == 'load':
            self._load_cache(config, args.file)
    
    def _list_cache_files(self, cache_dir: Path):
        """List all cache files"""
        print(f"\nCache files in {cache_dir}:")
        cache_files = list(cache_dir.glob('cache_*.json'))
        
        if not cache_files:
            print("  No cache files found")
            return
        
        total_size = 0
        for cache_file in sorted(cache_files):
            size = cache_file.stat().st_size
            total_size += size
            print(f"  • {cache_file.name} ({size:,} bytes)")
        
        print(f"\nTotal: {len(cache_files)} files, {total_size:,} bytes")
    
    def _clean_cache_files(self, cache_dir: Path, days: int):
        """Clean old cache files"""
        if not cache_dir.exists():
            print(f"Cache directory {cache_dir} does not exist")
            return
        
        from datetime import datetime, timedelta
        cutoff_date = datetime.now() - timedelta(days=days)
        
        removed_count = 0
        for cache_file in cache_dir.glob('cache_*.json'):
            try:
                date_str = cache_file.stem.replace('cache_', '')
                file_date = datetime.strptime(date_str, '%Y-%m-%d')
                
                if file_date < cutoff_date:
                    cache_file.unlink()
                    removed_count += 1
                    print(f"Removed: {cache_file.name}")
                    
            except Exception as e:
                print(f"Error processing {cache_file}: {e}")
        
        print(f"Cleaned up {removed_count} old cache files")
    
    def _save_cache(self, config: Dict[str, Any]):
        """Force save current cache"""
        try:
            sync_system = DataSyncSystem(config)
            success = sync_system.save_cache()
            if success:
                print("Cache saved successfully")
            else:
                print("Failed to save cache")
        except Exception as e:
            print(f"Error saving cache: {e}")
    
    def _load_cache(self, config: Dict[str, Any], cache_file: str):
        """Load specific cache file"""
        try:
            sync_system = DataSyncSystem(config)
            cache_path = Path(cache_file)
            if not cache_path.exists():
                print(f"Cache file {cache_file} not found")
                return
            
            records_loaded = sync_system._load_cache_file(cache_path)
            print(f"Loaded {records_loaded} records from {cache_file}")
            
        except Exception as e:
            print(f"Error loading cache: {e}")
    
    def test_system(self, args):
        """Run system tests"""
        print("Running Data Synchronization System Tests...")
        
        config = self.config.get('data_sync_system', {})
        config['cache_directory'] = './test_cache'  # Use test directory
        
        try:
            sync_system = DataSyncSystem(config)
            
            # Test records
            test_records = [
                CacheRecord(
                    spin_position=f"SP{i:03d}",
                    bucket_position=f"BP{i:03d}",
                    start_date="2024-01-01",
                    end_date="2024-01-02", 
                    lot_code=f"LOT{i:03d}",
                    main_line_id=f"ML{i:03d}",
                    data={"test": True, "value": i}
                ) for i in range(args.count)
            ]
            
            print(f"Testing with {len(test_records)} records...")
            
            # Test insertions and lookups
            start_time = time.time()
            
            for i, record in enumerate(test_records):
                # First check (cache miss expected)
                exists = sync_system.check_record_exists(record)
                
                # Insert if not exists
                if not exists:
                    sync_system.insert_record(record)
                
                # Second check (cache hit expected)
                sync_system.check_record_exists(record)
                
                if (i + 1) % 100 == 0:
                    print(f"Processed {i + 1} records...")
            
            duration = time.time() - start_time
            stats = sync_system.get_cache_statistics()
            
            print(f"\nTest Results:")
            print(f"  Records processed:  {len(test_records)}")
            print(f"  Duration:           {duration:.2f} seconds")
            print(f"  Records/second:     {len(test_records) / duration:.2f}")
            print(f"  Cache hit rate:     {stats['hit_rate']:.2%}")
            print(f"  Total queries:      {stats['total_queries']}")
            print(f"  Database queries:   {stats['db_queries']}")
            
            # Clean up test cache
            import shutil
            test_cache_dir = Path('./test_cache')
            if test_cache_dir.exists():
                shutil.rmtree(test_cache_dir)
                print("  Test cache cleaned up")
            
        except Exception as e:
            print(f"Test failed: {e}")
            sys.exit(1)


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(
        description="Data Synchronization System Management CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s start --daemon --verbose
  %(prog)s stats --json
  %(prog)s status
  %(prog)s cache list
  %(prog)s cache clean --days 7
  %(prog)s test --count 1000
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Start command
    start_parser = subparsers.add_parser('start', help='Start the synchronization system')
    start_parser.add_argument('--daemon', action='store_true', help='Run in daemon mode')
    start_parser.add_argument('--verbose', action='store_true', help='Verbose output')
    start_parser.add_argument('--cache-size', type=int, help='Max cache size')
    start_parser.add_argument('--cache-dir', help='Cache directory path')
    start_parser.add_argument('--retention-days', type=int, help='Cache file retention days')
    start_parser.set_defaults(func=lambda cli, args: cli.start_system(args))
    
    # Stats command
    stats_parser = subparsers.add_parser('stats', help='Show cache statistics')
    stats_parser.add_argument('--json', action='store_true', help='Output in JSON format')
    stats_parser.set_defaults(func=lambda cli, args: cli.show_stats(args))
    
    # Status command
    status_parser = subparsers.add_parser('status', help='Show system status')
    status_parser.add_argument('--json', action='store_true', help='Output in JSON format')
    status_parser.set_defaults(func=lambda cli, args: cli.show_status(args))
    
    # Cache management command
    cache_parser = subparsers.add_parser('cache', help='Manage cache files')
    cache_parser.add_argument('action', choices=['list', 'clean', 'save', 'load'],
                             help='Cache management action')
    cache_parser.add_argument('--days', type=int, default=7, 
                             help='Days for clean action')
    cache_parser.add_argument('--file', help='Cache file for load action')
    cache_parser.set_defaults(func=lambda cli, args: cli.manage_cache(args))
    
    # Test command
    test_parser = subparsers.add_parser('test', help='Run system tests')
    test_parser.add_argument('--count', type=int, default=1000, 
                            help='Number of test records')
    test_parser.set_defaults(func=lambda cli, args: cli.test_system(args))
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    cli = SyncCLI()
    args.func(cli, args)


if __name__ == '__main__':
    main()
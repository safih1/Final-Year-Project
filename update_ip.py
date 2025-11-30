"""
Script to update IP addresses across the entire SecureStep project
Run: python update_ip.py 192.168.1.8
"""
import sys
import os

def update_file(filepath, old_ip, new_ip):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if old_ip in content:
            updated_content = content.replace(old_ip, new_ip)
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(updated_content)
            print(f"✅ Updated: {filepath}")
            return True
        else:
            print(f"⏭️  Skipped (no changes): {filepath}")
            return False
    except Exception as e:
        print(f"❌ Error updating {filepath}: {e}")
        return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python update_ip.py <new_ip>")
        print("Example: python update_ip.py 192.168.1.8")
        sys.exit(1)
    
    new_ip = sys.argv[1]
    old_ips = ['192.168.1.5', '192.168.1.13']  # Previous IPs
    
    # Files to update
    files_to_update = [
        # Backend
        'secure_step_backend/secure_step_backend/settings.py',
        # SecureStep App
        'secure_step/lib/services/api_service.dart',
        'secure_step/lib/services/websocket_service.dart',
        'secure_step/lib/services/movement_service.dart',
        'secure_step/lib/services/audio_service.dart',
        # Admin Dashboard
        'admin_dashboard/index.html',
        # Companion App
        'police_companion_app/lib/services/api_service.dart',
        'police_companion_app/lib/screens/dashboard_screen.dart',
    ]
    
    print(f"\n🔄 Updating IP addresses to: {new_ip}\n")
    
    updated_count = 0
    for filepath in files_to_update:
        if os.path.exists(filepath):
            for old_ip in old_ips:
                if update_file(filepath, old_ip, new_ip):
                    updated_count += 1
                    break
        else:
            print(f"⚠️  File not found: {filepath}")
    
    print(f"\n✅ Updated {updated_count} files")
    print(f"🎯 All IP addresses changed to: {new_ip}\n")

if __name__ == '__main__':
    main()

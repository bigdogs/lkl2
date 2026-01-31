
import json
import random
import string
import datetime
import os

def generate_log_entry():
    """Generates a single log entry as a dictionary."""
    event_time = datetime.datetime.utcnow().isoformat() + "Z"
    
    log_entry = {
        "Event": {
            "paltformUtcTime": event_time,
            "telemetryEventName": "TestEvent-" + "".join(random.choices(string.ascii_uppercase + string.digits, k=10)),
            "SourcenodeId": random.randint(0, 2**64 - 1),
            "TargetnodeId": random.randint(0, 2**64 - 1)
        },
        "extra_data": "".join(random.choices(string.ascii_letters + string.digits, k=random.randint(900, 1900)))
    }
    return log_entry

def main():
    """Generates log file with a target size of ~1GB."""
    target_size_mb = 100
    target_size_bytes = target_size_mb * 1024 * 1024
    output_file = "/tmp/xxx.log"
    
    # Ensure the directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)

    current_size = 0
    with open(output_file, "w") as f:
        while current_size < target_size_bytes:
            log = generate_log_entry()
            log_line = json.dumps(log) + "\n"
            f.write(log_line)
            current_size += len(log_line.encode('utf-8'))

    print(f"Generated log file at {output_file} with size {current_size / (1024*1024*1024):.2f} GB")

if __name__ == "__main__":
    main()

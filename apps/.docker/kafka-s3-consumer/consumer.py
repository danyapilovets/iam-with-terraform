import os, time, json
from kafka import KafkaConsumer
import boto3

TOPIC   = os.getenv("KAFKA_TOPIC", "banking.transactions")
SERVERS = os.getenv("BOOTSTRAP_SERVERS", "kafka:9092").split(",")
BUCKET  = os.environ["S3_BUCKET"]
REGION  = os.getenv("AWS_REGION", "eu-central-1")

consumer = KafkaConsumer(
    TOPIC,
    bootstrap_servers=SERVERS,
    value_deserializer=lambda m: json.loads(m.decode()),
)

s3 = boto3.client("s3", region_name=REGION)
print("[consumer] started, writing to", BUCKET)
for msg in consumer:
    key = f"landing/{int(time.time())}.json"
    s3.put_object(Bucket=BUCKET, Key=key, Body=json.dumps(msg.value))
    print("uploaded", key)

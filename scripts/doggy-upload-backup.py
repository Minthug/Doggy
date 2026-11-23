#!/usr/bin/env python3
import hashlib
import os
import sys
from pathlib import Path

import boto3
from botocore.config import Config


backup_dir = Path(sys.argv[1])
bucket = os.environ["DOGGY_OBJECT_BUCKET"]
s3 = boto3.client(
    "s3",
    endpoint_url="https://kr.object.ncloudstorage.com",
    region_name="kr-standard",
    aws_access_key_id=os.environ["DOGGY_OBJECT_ACCESS_KEY"],
    aws_secret_access_key=os.environ["DOGGY_OBJECT_SECRET_KEY"],
    config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
)

for name in ("postgres.dump", "images.tar.gz", "SHA256SUMS"):
    path = backup_dir / name
    with path.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    key = f"doggy/{backup_dir.name}/{name}"
    s3.upload_file(str(path), bucket, key, ExtraArgs={"Metadata": {"sha256": digest}})
    remote = s3.head_object(Bucket=bucket, Key=key)
    if remote["ContentLength"] != path.stat().st_size or remote["Metadata"].get("sha256") != digest:
        raise RuntimeError(f"Object Storage verification failed: {key}")
    print(f"uploaded={key}")

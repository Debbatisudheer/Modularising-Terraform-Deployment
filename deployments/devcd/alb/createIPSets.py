from moto.wafv2 import mock_wafv2
import boto3
import json

@mock_wafv2
def main():
    # Your code here
    client = boto3.client("wafv2", region_name="us-east-1")
    # Example: create a fake IP set
    response = client.create_ip_set(
        Name="my-ipset",
        Scope="REGIONAL",
        Description="Test IP set",
        IPAddressVersion="IPV4",
        Addresses=["192.0.2.0/24"]
    )
    print("Created IP set:", response["Summary"])

if __name__ == "__main__":
    main()



import argparse
import json
from pathlib import Path
import re
import urllib.error
import urllib.request


API_VERSION = "v25"
API_ROOT = "https://googleads.googleapis.com/" + API_VERSION


class AdsError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        fp.close()
        raise AdsError("UNEXPECTED_REDIRECT")


def customerId(value):
    value = str(value).replace("-", "")
    if not re.fullmatch(r"[0-9]{10}", value):
        raise AdsError("VALID_CUSTOMER_ID_REQUIRED")
    return value


class AdsClient:
    def __init__(self, credentials):
        self.credentials = credentials
        for name in ("access_token", "developer_token"):
            if not isinstance(credentials.get(name), str) or not credentials[name].strip():
                raise AdsError("OAUTH_AND_DEVELOPER_TOKEN_REQUIRED_BEFORE_DISCOVERY")
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, path, payload=None, manager=True, login_id=None):
        headers = {
            "Authorization": "Bearer " + self.credentials["access_token"],
            "developer-token": self.credentials["developer_token"],
            "Content-Type": "application/json",
        }
        if login_id is None:
            login_id = self.credentials.get("manager_customer_id")
        if manager and login_id:
            headers["login-customer-id"] = customerId(login_id)
        body = None
        if payload is not None:
            body = json.dumps(payload).encode()
        request = urllib.request.Request(API_ROOT + path, headers=headers, data=body)
        try:
            with self.opener.open(request, timeout=30) as response:
                result = json.load(response)
        except urllib.error.HTTPError as error:
            status = error.code
            error.close()
            raise AdsError("GOOGLE_ADS_HTTP_" + str(status)) from None
        except (urllib.error.URLError, ValueError):
            raise AdsError("GOOGLE_ADS_REQUEST_FAILED") from None
        if not isinstance(result, dict) or result.get("error") or result.get("errors"):
            raise AdsError("GOOGLE_ADS_REQUEST_REJECTED")
        return result

    def listCustomers(self):
        return self.request("/customers:listAccessibleCustomers", manager=False)

    def listClients(self, manager_id):
        manager_id = customerId(manager_id)
        return self.request("/customers/" + manager_id + "/googleAds:search", {
            "query": "SELECT customer_client.id, customer_client.client_customer, customer_client.descriptive_name, customer_client.manager, customer_client.test_account FROM customer_client",
        }, login_id=manager_id)

    def identity(self):
        target = customerId(self.credentials.get("customer_id", ""))
        result = self.request("/customers/" + target + "/googleAds:search", {
            "query": "SELECT customer.id, customer.descriptive_name, customer.manager, customer.test_account FROM customer LIMIT 1",
        })
        rows = result.get("results", [])
        if len(rows) != 1:
            raise AdsError("TARGET_IDENTITY_NOT_VERIFIED")
        customer = rows[0].get("customer", {})
        if customerId(customer.get("id", "")) != target or type(customer.get("testAccount")) is not bool:
            raise AdsError("TARGET_IDENTITY_NOT_VERIFIED")
        if type(customer.get("manager")) is not bool:
            raise AdsError("TARGET_IDENTITY_NOT_VERIFIED")
        if customer["manager"]:
            raise AdsError("SELECT_OPERATING_CLIENT_ACCOUNT")
        target_mode = self.credentials.get("target_mode")
        if target_mode is None:
            target_mode = "production"
            if self.credentials.get("mode") in ("test", "pending-basic"):
                target_mode = "test"
        if target_mode not in ("test", "production"):
            raise AdsError("TARGET_MODE_NOT_VERIFIED")
        if target_mode == "test" and customer["testAccount"] is not True:
            raise AdsError("TEST_TARGET_REQUIRED_NO_REPORTS_OR_WRITES_SENT")
        return {"customer_id": target, "name": customer.get("descriptiveName", ""), "test_account": customer["testAccount"]}

    def operate(self, command, production_approved=False, query=None, resource=None, payload=None):
        target = self.identity()
        if not target["test_account"] and not production_approved:
            raise AdsError("PRODUCTION_TARGET_REQUIRES_APPROVAL")
        path = "/customers/" + target["customer_id"] + "/"
        if command == "search":
            if not query:
                raise AdsError("QUERY_REQUIRED")
            return self.request(path + "googleAds:search", {"query": query})
        if command == "mutate" and resource in ("campaigns", "campaignBudgets") and isinstance(payload, dict):
            return self.request(path + resource + ":mutate", payload)
        raise AdsError("SUPPORTED_OPERATION_REQUIRED")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--credentials", default="~/.config/google-ads/credentials.json")
    parser.add_argument("--production-approved", action="store_true")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("version")
    commands.add_parser("list-customers")
    clients = commands.add_parser("list-clients")
    clients.add_argument("--manager-id", required=True)
    commands.add_parser("inspect")
    search = commands.add_parser("search")
    search.add_argument("--query", required=True)
    mutate = commands.add_parser("mutate")
    mutate.add_argument("--resource", choices=("campaigns", "campaignBudgets"), required=True)
    mutate.add_argument("--payload-file", required=True)
    args = parser.parse_args()
    if args.command == "version":
        print(API_VERSION)
        return 0
    try:
        credentials = json.loads(Path(args.credentials).expanduser().read_text())
        client = AdsClient(credentials)
        if args.command == "list-customers":
            result = client.listCustomers()
        elif args.command == "list-clients":
            result = client.listClients(args.manager_id)
        elif args.command == "inspect":
            result = client.identity()
        elif args.command == "search":
            result = client.operate("search", args.production_approved, query=args.query)
        else:
            payload = json.loads(Path(args.payload_file).read_text())
            result = client.operate("mutate", args.production_approved, resource=args.resource, payload=payload)
        print(json.dumps(result))
    except AdsError as error:
        print(str(error))
        return 1
    except (OSError, ValueError, KeyError, TypeError):
        print("GOOGLE_ADS_STATE_NOT_VERIFIED")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

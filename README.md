# porkbun-cli

A tiny shell script for interacting with the [Porkbun API](https://porkbun.com/api/json/v3/documentation).

**See the [docs to get an API key](https://porkbun.com/api/json/v3/documentation#Authentication) first.**

**[Quick start](#Examples)**

## Dependencies

- curl (widely available)
- getopt (widely available)
- jq

## Configuration

To avoid having having your credentials stored in the command history, configure a file in `~/.config/porkbun-cli/credentials` with the content:
```
PORKBUN_API_KEY=<api-key>
PORKBUN_SECRET_API_KEY<secret-api-key>
```

## Examples

- Directly passing in credentials (see [configuration section](#configuration) to store credentials in a file)
```sh
./porkbun-cli.sh \
  --api-key pk_1234 \
  --secret-api-key sk_1234 -- \
  retrieve example.com
```

- Create a record ([reference](https://porkbun.com/api/json/v3/documentation#DNS%20Create%20Record))
```sh
./porkbun-cli.sh -- \
  create example.com www \
  --type A \
  --content 1.1.1.1
```

- Edit record by domain and id ([reference](https://porkbun.com/api/json/v3/documentation#DNS%20Edit%20Record%20by%20Domain%20and%20ID))
```sh
./porkbun-cli.sh -- \
  edit example.com 1234567890 \
  --type A \
  --name www \
  --content 1.1.1.1
```

- Edit record by domain, subdomain, and type ([reference](https://porkbun.com/api/json/v3/documentation#DNS%20Edit%20Record%20by%20Domain,%20Subdomain%20and%20Type))
```sh
./porkbun-cli.sh -- \
  edit-by-name-type example.com www \
  --type A \
  --content 1.1.1.1
```

- Delete record by id ([reference](https://porkbun.com/api/json/v3/documentation#DNS%20Delete%20Record%20by%20Domain%20and%20ID))
```sh
./porkbun-cli.sh -- \
  delete example.com 1234567890
```

- Delete record by domain, subdomain, and type ([reference](https://porkbun.com/api/json/v3/documentation#DNS%20Delete%20Records%20by%20Domain,%20Subdomain%20and%20Type))
```sh
./porkbun-cli.sh -- \
  delete-by-name-type example.com www \
  --type A
```

- Retrieve records by domain ([reference](https://porkbun.com/api/json/v3/documentation#DNS%20Retrieve%20Records%20by%20Domain%20or%20ID))
```sh
./porkbun-cli.sh -- \
  retrieve example.com
```

- Retrieve records by domain and id ([reference](https://porkbun.com/api/json/v3/documentation#DNS%20Retrieve%20Records%20by%20Domain%20or%20ID))
```sh
./porkbun-cli.sh -- \
  retrieve example.com 1234567890
```

- Upsert record by domain
```sh
# if no records exist for this domain, subdomain, type, then create it
# if one record exists for this domain, subdomain, type, then update it
# otherwise, error unless --multiple-behavior is set (see below)
./porkbun-cli.sh -- \
  upsert-by-name-type example.com www \
  --type A \
  --content 1.1.1.1
```

- Uniquely upsert record by domain
```sh
# if no records exist for this domain, subdomain, type, then create it
# if one record exists for this domain, subdomain, type, then update it
# otherwise, delete all records for this domain, subdomain, type and then
# create a new record
./porkbun-cli.sh -- \
  upsert-by-name-type example.com www \
  --type A \
  --content 1.1.1.1 \
  --multiple-behavior unique
```

- Append upsert record by domain
```sh
# if no records exist for this domain, subdomain, type, then create it
# if one record exists for this domain, subdomain, type, then update it
# otherwise, append a new record
./porkbun-cli.sh -- \
  upsert-by-name-type example.com www \
  --type A \
  --content 1.1.1.1 \
  --multiple-behavior append
```

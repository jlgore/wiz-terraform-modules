# Example: probe-owner-query

A small helper for inspecting exactly what `wiz-v2_graphql_query` returns for a
`SUBSCRIPTION` lookup. Use it when tuning the
[`wiz-graph`](../../modules/resolvers/wiz-graph) resolver to a tenant whose graph
shape differs from the default.

## Run

```bash
terraform init
terraform apply -var 'external_ids=["<your-subscription-id>"]'
terraform output -json decoded_result   # inspect the envelope
```

Look for: the path to the entities array, where `externalId` lives in
`properties`, and how tags are represented (`properties.tags` map). Those three
answers are what the resolver keys off.

> Produces Terraform state containing whatever your tenant returns — it's
> git-ignored. Don't commit it.

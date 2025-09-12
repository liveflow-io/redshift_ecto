# RedshiftEcto

[Ecto](https://github.com/elixir-ecto/ecto) Adapter for [AWS Redshift](https://aws.amazon.com/redshift/).

This adapter is based on Ecto's builtin [Postgres adapter](https://hexdocs.pm/ecto/Ecto.Adapters.Postgres.html). It delegates some functions to it but changes the implementation of most that are incompatible with Redshift. The differences are detailed in the documentation.

Documentation can be found at [https://hexdocs.pm/redshift_ecto](https://hexdocs.pm/redshift_ecto).

## Installation

Add `redshift_ecto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:redshift_ecto, "~> 0.2.0"}
  ]
end
```

## Connecting

`RedshiftEcto` communicates with Redshift through the
[Redshift Data API](https://docs.aws.amazon.com/redshift/latest/mgmt/data-api.html)
via the [`AWS.RedshiftData`](https://hexdocs.pm/aws/AWS.RedshiftData.html)
module. The repository configuration accepts the connection options required
by the AWS client.

### Production cluster

Provide your AWS credentials through the environment or explicitly in the
configuration. Specify the cluster identifier, database name and either a
database user or a Secrets Manager ARN:

```elixir
config :my_app, MyApp.Repo,
  adapter: RedshiftEcto,
  region: "us-east-1",
  cluster_identifier: "my-redshift-cluster",
  database: "dev",
  db_user: "awsuser"
  # or: secret_arn: "arn:aws:secretsmanager:..."
```

### Localstack

When developing locally you can point the adapter at a Localstack instance
that provides the Redshift Data API. Use the Localstack endpoint and dummy
credentials:

```elixir
config :my_app, MyApp.Repo,
  adapter: RedshiftEcto,
  region: "us-east-1",
  cluster_identifier: "local",
  database: "dev",
  db_user: "test",
  access_key_id: "test",
  secret_access_key: "test",
  endpoint: "http://localhost:4566"
```

## Testing

Redshift doesn't support nested transactions which makes the builtin sandbox implementation of Ecto unusable for testing. RedshiftEcto depends on [ecto_replay_sandbox](https://github.com/jumpn/ecto_replay_sandbox) which implements pseudo transactions that provides a similar experience in testing to the Ecto's sandbox. See the integration tests of the adapter for an example on how to use it.

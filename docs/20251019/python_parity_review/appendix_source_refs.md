# Appendix: Source References

Use this appendix to quickly locate the code underpinning the analyses in the other documents.

## Elixir Client (`weaviate_ex`)

- Client struct & config: `lib/weaviate_ex/client.ex:1`, `lib/weaviate_ex/client/config.ex:1`
- HTTP protocol implementation: `lib/weaviate_ex/protocol/http/client.ex:1`
- Error helpers: `lib/weaviate_ex/error.ex:1`
- Core entry module: `lib/weaviate_ex.ex:1`
- Collections schema APIs: `lib/weaviate_ex/collections.ex:61`
- Tenant APIs: `lib/weaviate_ex/api/tenants.ex:31`
- Object CRUD APIs: `lib/weaviate_ex/api/data.ex:91`
- Batch APIs: `lib/weaviate_ex/batch.ex:83`, `lib/weaviate_ex/api/batch.ex:35`
- GraphQL query builder: `lib/weaviate_ex/query.ex:59`
- Filter DSL: `lib/weaviate_ex/filter.ex:53`
- Advanced query helpers: `lib/weaviate_ex/api/query_advanced.ex:43`
- Aggregation API: `lib/weaviate_ex/api/aggregate.ex:64`
- Generative API: `lib/weaviate_ex/api/generative.ex:60`
- Vector config builders: `lib/weaviate_ex/api/vector_config.ex:1`
- Embedded server management: `lib/weaviate_ex/embedded.ex:1`
- Health checks: `lib/weaviate_ex/health.ex:31`

## Python Client (`weaviate-python-client`)

- Client namespaces and attributes: `weaviate-python-client/weaviate/client.py:32`
- Connection helpers: `weaviate-python-client/weaviate/connect/helpers.py:61`
- Auth flows: `weaviate-python-client/weaviate/auth.py:11`
- gRPC query implementation: `weaviate-python-client/weaviate/collections/grpc/query.py:1`
- Collections config executor: `weaviate-python-client/weaviate/collections/config/executor.py:422`
- Batch client wrapper: `weaviate-python-client/weaviate/collections/batch/client.py:28`
- Proto definitions: `weaviate-python-client/weaviate/proto`
- Warning and validator utilities: `weaviate-python-client/weaviate/warnings.py`, `weaviate-python-client/weaviate/validator.py`

These references serve as the authoritative anchors for future development and validation efforts.

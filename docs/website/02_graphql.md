# Search (GraphQL | gRPC)

## API

Weaviate offers GraphQL and gRPC APIs for queries.

We recommend using a Weaviate client library, which abstracts away the underlying API calls and makes it easier to integrate Weaviate into your application.

However, you can query Weaviate directly using GraphQL with a `POST` request to the `/graphql` endpoint, or write your own gRPC calls based on the gRPC protobuf specification.

### All references

All references have their individual subpages. Click on one of the references below for more information.

*   [Object-level queries](<https://weaviate.io/developers/weaviate/api/graphql/get>)
*   [Aggregate](<https://weaviate.io/developers/weaviate/api/graphql/aggregate>)
*   [Search operators](<https://weaviate.io/developers/weaviate/api/graphql/search-operators>)
*   [Conditional filters](<https://weaviate.io/developers/weaviate/api/graphql/filters>)
*   [Additional operators](<https://weaviate.io/developers/weaviate/api/graphql/additional-operators>)
*   [Additional properties](<https://weaviate.io/developers/weaviate/api/graphql/additional-properties>)
*   [Explore](<https://weaviate.io/developers/weaviate/api/graphql/explore>)

## GraphQL API

### Why GraphQL?

GraphQL is a query language built on using graph data structures. It is an efficient method of data retrieval and mutation, since it mitigates the common over-fetching and under-fetching problems of other query languages.

**GraphQL is case-sensitive**

GraphQL is case-sensitive (reference), so make sure to use the correct casing when writing your queries.

### Query structure

You can `POST` a GraphQL query to Weaviate as follows:

```bash
curl http://localhost/v1/graphql -X POST -H 'Content-type: application/json' -d '{GraphQL query}'
```

A GraphQL JSON object is defined as:

```json
{
    "query": "{ # GRAPHQL QUERY }"
}
```

GraphQL queries follow a defined structure. Queries are structured as follows:

```graphql
{
  <Function> {
      <Collection> {
        <property>
        _<underscore-property>
      }
  }
}
```

### Limitations

GraphQL integer data currently only supports `int32`, and does not support `int64`. This means that currently integer data fields in Weaviate with integer values larger than `int32`, will not be returned using GraphQL queries. We are working on solving this issue. As current workaround is to use a `string` instead.

### Consistency level

GraphQL (`Get`) queries are run with a tunable consistency level.

## gRPC API

Starting with Weaviate `v1.19.0`, a gRPC interface is being progressively added to Weaviate.

gRPC is a high-performance, open-source universal RPC framework that is contract-based and can be used in any environment. It is based on HTTP/2 and Protocol Buffers, and is therefore very fast and efficient.

Read more about the gRPC API [here](<https://weaviate.io/developers/weaviate/api/grpc>).

## Questions and feedback

If you have any questions or feedback, let us know in the [user forum](<https://forum.weaviate.io/>).

### Technical questions

If you have questions feel free to post on our [Community forum](<https://forum.weaviate.io/>).

### Documentation feedback

Leave feedback by opening a [GitHub issue](<https://github.com/weaviate/weaviate-io/issues/new/choose>).

[Edit this page](<https://github.com/weaviate/weaviate-io/edit/main/site/content/en/developers/weaviate/api/graphql-grpc.mdx>)

---

### Documentation

*   [Weaviate Database](<https://weaviate.io/developers/weaviate>)
*   [Deployment documentation](<https://weaviate.io/developers/weaviate/installation>)
*   [Weaviate Cloud](<https://weaviate.io/developers/wcs>)
*   [Weaviate Agents](<https://weaviate.io/developers/weaviate/agents>)
*   [Support](<https://weaviate.io/developers/weaviate/support>)
*   [Forum](<https://forum.weaviate.io/>)
*   [Slack](<https://weaviate.io/slack>)

### API

*   [All references](<https://weaviate.io/developers/weaviate/api>)
*   [GraphQL API](<https://weaviate.io/developers/weaviate/api/graphql>)
    *   [Why GraphQL?](<https://weaviate.io/developers/weaviate/api/graphql-grpc#why-graphql>)
    *   [Query structure](<https://weaviate.io/developers/weaviate/api/graphql-grpc#query-structure>)
    *   [Limitations](<https://weaviate.io/developers/weaviate/api/graphql-grpc#limitations>)
    *   [Consistency level](<https://weaviate.io/developers/weaviate/api/graphql-grpc#consistency-level>)
*   [gRPC API](<https://weaviate.io/developers/weaviate/api/grpc>)

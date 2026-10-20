[**popopx-chat**](README.md)

***

[popopx-chat](README.md) / [core](Namespace.core.md) / loadLibrary

# Function: loadLibrary()

> **loadLibrary**(`backend`): `Promise`\<`void`\>

Defined in: [src/core.ts:13](../core.ts#L13)

Resolve (downloading on first use) and load libpopopx for the backend.
One libpopopx per process: the Haskell runtime is initialized once, and another backend is rejected.

## Parameters

### backend

[`Backend`](core.TypeAlias.Backend.md)

## Returns

`Promise`\<`void`\>

# Path Mapping Table and `docs/src-notes/INDEX.md` Example

Read this file when deriving a document path or creating `docs/src-notes/INDEX.md`. The derivation rules in `SKILL.md` §4.1 and the INDEX rules in §4.4 take precedence.

## Level-by-level path mapping

Shown for a single-segment root (`src/`) and a multi-segment root (`packages/api/src/`).

| Source | Document (relative to `docs/src-notes/`) |
|---|---|
| Folder `src/` (level 1) | `src.md` |
| File `src/index.ts` | `src/index.ts.md` |
| Folder `src/services/` (level 2) | `src/services.md` |
| File `src/services/login.ts` | `src/services/login.ts.md` |
| Folder `src/services/auth/` (level 3) | `src/services/auth.md` |
| File `src/services/auth/login.ts` | `src/services/auth/login.ts.md` |
| Folder `src/services/auth/oauth/` (level 4) | `src/services/auth/oauth.md` |
| File `src/services/auth/oauth/google.ts` | `src/services/auth/oauth/google.ts.md` |
| Folder `src/services/auth/oauth/providers/` (level 5 → flattened) | `src/services/auth/oauth/providers.md` |
| File `src/services/auth/oauth/providers/github.ts` | `src/services/auth/oauth/providers__github.ts.md` |
| File `src/services/auth/oauth/providers/github.css` | `src/services/auth/oauth/providers__github.css.md` |
| Folder `src/services/auth/oauth/providers/scopes/` (level 6) | `src/services/auth/oauth/providers__scopes.md` |
| File `src/services/auth/oauth/providers/scopes/read.ts` | `src/services/auth/oauth/providers__scopes__read.ts.md` |
| Folder `packages/api/src/` (multi-segment root → each segment counted separately, level 3) | `packages/api/src.md` |
| File `packages/api/src/services/auth/login.ts` (root is level 3, `services/` is level 4) | `packages/api/src/services/auth__login.ts.md` |

## Mapping table for a root with a base package

Declared in INDEX.md as `- src/main/java/com/example/shop/ — base package com.example.shop`. The base package name is level 1 and the first segment under the root is level 2.

| Source | Document (relative to `docs/src-notes/`) |
|---|---|
| Folder `src/main/java/com/example/shop/` (base package = level 1) | `com.example.shop.md` |
| File `src/main/java/com/example/shop/ShopApplication.java` | `com.example.shop/ShopApplication.java.md` |
| Folder `src/main/java/com/example/shop/order/` (level 2) | `com.example.shop/order.md` |
| File `src/main/java/com/example/shop/order/OrderModule.java` | `com.example.shop/order/OrderModule.java.md` |
| Folder `src/main/java/com/example/shop/order/service/` (level 3) | `com.example.shop/order/service.md` |
| File `src/main/java/com/example/shop/order/service/OrderService.java` | `com.example.shop/order/service/OrderService.java.md` |
| Folder `src/main/java/com/example/shop/order/service/impl/` (level 4) | `com.example.shop/order/service/impl.md` |
| File `src/main/java/com/example/shop/order/service/impl/OrderServiceImpl.java` | `com.example.shop/order/service/impl/OrderServiceImpl.java.md` |
| Folder `src/main/java/com/example/shop/order/service/impl/dto/` (level 5 → flattened) | `com.example.shop/order/service/impl/dto.md` |
| File `src/main/java/com/example/shop/order/service/impl/dto/Line.java` | `com.example.shop/order/service/impl/dto__Line.java.md` |
| File `src/main/java/module-info.java` (outside the base package → declare root `src/main/java/` separately, default rule) | `src/main/java/module-info.java.md` |
| File `src/shop/orders/services/pricing/discount.py` (root `src/shop/`, base package `shop`) | `shop/orders/services/pricing/discount.py.md` |
| File `src/Shop.Order/Services/OrderService.cs` (root `src/Shop.Order/`, base package `Shop.Order`) | `Shop.Order/Services/OrderService.cs.md` |

## INDEX.md example

```markdown
# Source Index

## Source roots

- `src/`
- `src/main/java/com/example/shop/` — base package `com.example.shop`

## com.example.shop/order/service

| Source | Summary | Doc | Specification |
|---|---|---|---|
| src/main/java/com/example/shop/order/service/OrderService.java | Order creation and cancellation | [doc](com.example.shop/order/service/OrderService.java.md) | standard |

## src/services/auth

| Source | Summary | Doc | Specification |
|---|---|---|---|
| src/services/auth/login.ts | Login handling | [doc](src/services/auth/login.ts.md) | standard |
| src/services/auth/logout.ts | Logout handling | [doc](src/services/auth/logout.ts.md) | standard |

## src/utils

| Source | Summary | Doc | Specification |
|---|---|---|---|
| src/utils/format.ts | Date/number format helpers | [doc](src/utils/format.ts.md) | minimal |
```

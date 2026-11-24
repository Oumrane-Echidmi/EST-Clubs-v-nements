# Dependency security review

Reviewed 2026-11-24. Lifecycle scripts are disabled in .npmrc. Prisma generation is explicit; bcrypt and sharp use bundled platform binaries. Runtime integrations, validation, uploads and the full PostgreSQL suite exercise the patched dependency versions in package-lock.json.

Updated vulnerable initial choices to Prisma/client/adapter 7.10.1, Firebase Admin 14.5.1, Nodemailer 10.6.1 and sharp 0.35.5. Jest 29.7 is aligned with ts-jest.

## Deferred advisory

`npm audit` reports 3 high entries from one underlying advisory: effect Schema.TemplateLiteral ReDoS (GHSA-7589-6fvf-x4pw), propagated through @prisma/config and prisma. The CLI currently resolves effect 3.22.0; audit proposes downgrading Prisma to 6.12.0. Effect 4 is a breaking upgrade and is not force-overridden.

Reachability: prisma/config is used by the trusted local CLI config during generation/migrations, not imported by src/main.ts or the API request path. This application does not compile user-controlled Effect schemas or TemplateLiteral expressions. The Prisma client runtime uses the pg adapter. npm's production audit still lists the CLI because Prisma client declares it as an optional peer; that is a package-tree finding, not evidence that the server imports the CLI.

Mitigation: do not accept remote Prisma configuration or schemas; run migration/generation only from the reviewed repository. No generic user schema compilation endpoint exists. Revisit by 2026-12-24 or before any production release, whichever comes first, and adopt the first compatible patched Prisma/Effect release. Do not use `npm audit fix --force` to conceal this finding.

Advisory: https://github.com/advisories/GHSA-7589-6fvf-x4pw
Prisma upgrade reference: https://www.prisma.io/docs/guides/upgrade-prisma-orm/v7

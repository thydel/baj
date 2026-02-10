# 2026-02-10

- Add a new tag

```bash
cmnt='infra-prov-2026'
```

# 2026-01-12

- Add a new tag

```bash
cmnt='infra-procv-2026'
```

# 2025-12-24

- Add a new tag

```bash
cmnt='Space evol ssp'
```

# 2025-12-22

- Use to add a new tag

```bash
git switch main
tag=$(date +%F)-a
cmnt='First baj version'
git tag -a $tag -m "$cmnt"
git push origin $tag
```

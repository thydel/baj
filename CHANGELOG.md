# 2025-12-24

- Add a new tag

# 2025-12-22

- Use to add a new tag

```bash
git switch main
tag=$(date +%F)-a
cmnt='First baj version'
git tag -a $tag -m "$cmnt"
git push origin $tag
```

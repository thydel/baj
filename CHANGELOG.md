# 2025-12-22

```bash
git switch main
tag=$(date +%F)-a
cmnt='First baj version'
git tag -a $tag -m "$cmnt"
git push origin $tag
```

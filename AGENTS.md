# WoodCraft Workspace Guidelines

## Automatic GitHub Sync
- Remote repository: `https://github.com/vanithathanvitechnologies/woodcraft.git` (branch: `main`).
- Whenever code or project files in this workspace are created, edited, or deleted as part of a task, automatically stage (`git add -A`), commit with a clear descriptive message, and push (`git push origin main`) once changes are verified.
- Never commit ignored secret files (such as `backend/.env`), live cPanel credentials, `node_modules/`, Flutter `build/` outputs, or `.gradle/` caches.

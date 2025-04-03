export PYTHONDONTWRITEBYTECODE=1

# Download Routers Locally
PYTHONDONTWRITEBYTECODE=1 make download

# Configure API Key for Build Endpoints models
python3 workbench/init.py

# Adjust new content to avoid perm issues
chmod -R 775 demo
chmod -R 775 routers

exit 0
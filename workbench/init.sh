# Adjust perms for locally downloaded content
chmod -R 775 demo
chmod -R 775 routers

# Download Routers Locally
make download

# Configure API Key for Build Endpoints models
python3 workbench/init.py

exit 0
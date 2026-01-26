from flask import Blueprint, jsonify
import os
import MetaTrader5 as mt5
from flasgger import swag_from

health_bp = Blueprint('health', __name__)

@health_bp.route('/health')
@swag_from({
    'tags': ['Health'],
    'responses': {
        200: {
            'description': 'Health check successful',
            'schema': {
                'type': 'object',
                'properties': {
                    'status': {'type': 'string'},
                    'mt5_connected': {'type': 'boolean'},
                    'mt5_initialized': {'type': 'boolean'}
                }
            }
        }
    }
})
def health_check():
    """
    Health Check Endpoint
    ---
    description: Check the health status of the application and MT5 connection.
    responses:
      200:
        description: Health check successful
    """
    initialized = mt5.initialize()
    return jsonify({
        "status": "healthy",
        "mt5_connected": True,
        "mt5_initialized": initialized
    }), 200

@health_bp.route('/status')
@swag_from({
    'tags': ['Health'],
    'responses': {
        200: {
            'description': 'Detailed status information',
        }
    }
})
def detailed_status():
    """
    Detailed Status Endpoint
    ---
    description: Get detailed status of MT5 installation and connection.
    responses:
      200:
        description: Status information
    """
    import subprocess
    
    status = {
        "flask": "running",
        "mt5_library": {
            "available": MT5_AVAILABLE,
            "initialized": False
        },
        "mt5_installation": {
            "installed": False,
            "running": False,
            "path": None
        },
        "wine": {
            "available": False,
            "prefix": None
        }
    }
    
    # Check MT5 library
    if MT5_AVAILABLE and mt5 is not None:
        try:
            status["mt5_library"]["initialized"] = mt5.initialize()
        except Exception:
            pass
    
    # Check MT5 installation
    mt5_paths = [
        "/config/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe",
        "/config/.wine/drive_c/Program Files (x86)/MetaTrader 5/terminal64.exe"
    ]
    
    for path in mt5_paths:
        if os.path.exists(path):
            status["mt5_installation"]["installed"] = True
            status["mt5_installation"]["path"] = path
            break
    
    # Check if MT5 process is running
    try:
        result = subprocess.run(
            ["pgrep", "-f", "terminal64.exe"],
            capture_output=True,
            text=True,
            timeout=2
        )
        status["mt5_installation"]["running"] = result.returncode == 0
    except Exception:
        pass
    
    # Check Wine
    wine_prefix = os.environ.get("WINEPREFIX", "/config/.wine")
    if os.path.exists(wine_prefix):
        status["wine"]["prefix"] = wine_prefix
        status["wine"]["available"] = os.path.exists(os.path.join(wine_prefix, "system.reg"))
    
    # Check setup log for installation progress
    setup_log = "/var/log/mt5_setup.log"
    if os.path.exists(setup_log):
        try:
            with open(setup_log, 'r') as f:
                lines = f.readlines()
                # Get last 5 lines for recent status
                status["setup_log_recent"] = [line.strip() for line in lines[-5:] if line.strip()]
        except Exception:
            pass
    
    return jsonify(status), 200
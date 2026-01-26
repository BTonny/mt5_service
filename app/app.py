import logging
import os
from flask import Flask
from dotenv import load_dotenv

# Try to import MetaTrader5, but don't fail if it's not available
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
except ImportError as e:
    logging.warning(f"MetaTrader5 library not available: {e}. API will work but MT5 features will be unavailable.")
    mt5 = None
    MT5_AVAILABLE = False

from flasgger import Swagger
from werkzeug.middleware.proxy_fix import ProxyFix
from swagger import swagger_config

# Import routes
from routes.health import health_bp
from routes.symbol import symbol_bp
from routes.data import data_bp
from routes.position import position_bp
from routes.order import order_bp
from routes.history import history_bp
from routes.error import error_bp

load_dotenv()
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['PREFERRED_URL_SCHEME'] = 'https'

swagger = Swagger(app, config=swagger_config)

# Register blueprints
app.register_blueprint(health_bp)
app.register_blueprint(symbol_bp)
app.register_blueprint(data_bp)
app.register_blueprint(position_bp)
app.register_blueprint(order_bp)
app.register_blueprint(history_bp)
app.register_blueprint(error_bp)

app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1, x_host=1)

if __name__ == '__main__':
    # Try to initialize MT5, but don't fail if it's not available
    if MT5_AVAILABLE and mt5 is not None:
        try:
            if mt5.initialize():
                logger.info("MT5 initialized successfully.")
            else:
                logger.warning("MT5 initialization failed. API will work but MT5 features will be unavailable.")
                logger.warning("This is normal if MT5 is still installing or not available.")
        except Exception as e:
            logger.warning(f"MT5 initialization error: {str(e)}. API will continue without MT5.")
    else:
        logger.warning("MetaTrader5 library not available. API will work but MT5 features will be unavailable.")
    
    # Start Flask server regardless of MT5 status
    port = int(os.environ.get('MT5_API_PORT', 5001))
    logger.info(f"Starting Flask server on port {port}...")
    app.run(host='0.0.0.0', port=port, debug=False)
from flask import Blueprint, jsonify
import MetaTrader5 as mt5
from flasgger import swag_from
import logging

health_bp = Blueprint('health', __name__)
logger = logging.getLogger(__name__)

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
    initialized = mt5.initialize() if mt5 is not None else False
    return jsonify({
        "status": "healthy",
        "mt5_connected": mt5 is not None,
        "mt5_initialized": initialized
    }), 200

@health_bp.route('/terminal_info', methods=['GET'])
@swag_from({
    'tags': ['Health'],
    'responses': {
        200: {
            'description': 'Terminal information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'name': {'type': 'string'},
                    'company': {'type': 'string'},
                    'path': {'type': 'string'},
                    'build': {'type': 'integer'},
                    'connected': {'type': 'boolean'},
                    'trade_allowed': {'type': 'boolean'},
                    'ping_last': {'type': 'integer'}
                }
            }
        },
        400: {
            'description': 'Failed to retrieve terminal information.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_terminal_info():
    """
    Get Terminal Information
    ---
    description: Retrieve terminal information including connection status and capabilities.
    """
    try:
        terminal_info = mt5.terminal_info()
        if terminal_info is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to get terminal information",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        # Convert to dictionary
        terminal_dict = terminal_info._asdict()
        
        return jsonify(terminal_dict), 200
    
    except Exception as e:
        logger.error(f"Error in get_terminal_info: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
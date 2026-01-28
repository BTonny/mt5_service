from flask import Blueprint, jsonify
import MetaTrader5 as mt5
import logging
from flasgger import swag_from

account_bp = Blueprint('account', __name__)
logger = logging.getLogger(__name__)

@account_bp.route('/account_info', methods=['GET'])
@swag_from({
    'tags': ['Account'],
    'responses': {
        200: {
            'description': 'Account information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'login': {'type': 'integer'},
                    'server': {'type': 'string'},
                    'balance': {'type': 'number'},
                    'equity': {'type': 'number'},
                    'margin': {'type': 'number'},
                    'margin_free': {'type': 'number'},
                    'margin_level': {'type': 'number'},
                    'profit': {'type': 'number'},
                    'currency': {'type': 'string'},
                    'leverage': {'type': 'integer'},
                    'trade_mode': {'type': 'integer'},
                    'trade_allowed': {'type': 'boolean'},
                    'trade_expert': {'type': 'boolean'},
                    'name': {'type': 'string'},
                    'company': {'type': 'string'}
                }
            }
        },
        400: {
            'description': 'Failed to retrieve account information.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_account_info():
    """
    Get Account Information
    ---
    description: Retrieve comprehensive account information including balance, equity, margin, and trading status.
    """
    try:
        account_info = mt5.account_info()
        if account_info is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to get account information",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        # Convert to dictionary
        account_dict = account_info._asdict()
        
        return jsonify(account_dict), 200
    
    except Exception as e:
        logger.error(f"Error in get_account_info: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

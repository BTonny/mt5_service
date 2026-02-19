from flask import Blueprint, jsonify
import MetaTrader5 as mt5
import logging
from flasgger import swag_from
from mt5_worker import run_mt5
from cache import get as cache_get, set as cache_set

account_bp = Blueprint('account', __name__)
logger = logging.getLogger(__name__)
ACCOUNT_CACHE_KEY = ("account_info",)
ACCOUNT_TTL = 2

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
        cached = cache_get(ACCOUNT_CACHE_KEY)
        if cached is not None:
            return jsonify(cached), 200
        account_info = run_mt5(mt5.account_info)
        if account_info is None:
            error_code, error_str = run_mt5(mt5.last_error)
            return jsonify({
                "error": "Failed to get account information",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        # Convert to dictionary
        account_dict = account_info._asdict()
        cache_set(ACCOUNT_CACHE_KEY, account_dict, ACCOUNT_TTL)
        return jsonify(account_dict), 200
    
    except Exception as e:
        logger.error(f"Error in get_account_info: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

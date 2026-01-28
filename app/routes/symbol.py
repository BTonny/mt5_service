from flask import Blueprint, jsonify, request
import MetaTrader5 as mt5
from flasgger import swag_from
import logging

symbol_bp = Blueprint('symbol', __name__)
logger = logging.getLogger(__name__)

@symbol_bp.route('/symbol_info_tick/<symbol>', methods=['GET'])
@swag_from({
    'tags': ['Symbol'],
    'parameters': [
        {
            'name': 'symbol',
            'in': 'path',
            'type': 'string',
            'required': True,
            'description': 'Symbol name to retrieve tick information.'
        }
    ],
    'responses': {
        200: {
            'description': 'Tick information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'bid': {'type': 'number'},
                    'ask': {'type': 'number'},
                    'last': {'type': 'number'},
                    'volume': {'type': 'integer'},
                    'time': {'type': 'integer'}
                }
            }
        },
        404: {
            'description': 'Failed to get symbol tick info.'
        }
    }
})
def get_symbol_info_tick_endpoint(symbol):
    """
    Get Symbol Tick Information
    ---
    description: Retrieve the latest tick information for a given symbol.
    """
    tick = mt5.symbol_info_tick(symbol)
    if tick is None:
        return jsonify({"error": "Failed to get symbol tick info"}), 404
    
    tick_dict = tick._asdict()
    return jsonify(tick_dict)

@symbol_bp.route('/symbol_info/<symbol>', methods=['GET'])
@swag_from({
    'tags': ['Symbol'],
    'parameters': [
        {
            'name': 'symbol',
            'in': 'path',
            'type': 'string',
            'required': True,
            'description': 'Symbol name to retrieve information.'
        }
    ],
    'responses': {
        200: {
            'description': 'Symbol information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'name': {'type': 'string'},
                    'path': {'type': 'string'},
                    'description': {'type': 'string'},
                    'volume_min': {'type': 'number'},
                    'volume_max': {'type': 'number'},
                    'volume_step': {'type': 'number'},
                    'price_digits': {'type': 'integer'},
                    'spread': {'type': 'number'},
                    'points': {'type': 'integer'},
                    'trade_mode': {'type': 'integer'},
                    # Add other relevant fields as needed
                }
            }
        },
        404: {
            'description': 'Failed to get symbol info.'
        }
    }
})
def get_symbol_info(symbol):
    """
    Get Symbol Information
    ---
    description: Retrieve detailed information for a given symbol.
    """
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        return jsonify({"error": "Failed to get symbol info"}), 404
    
    symbol_info_dict = symbol_info._asdict()
    return jsonify(symbol_info_dict)

@symbol_bp.route('/symbol_select/<symbol>', methods=['POST'])
@swag_from({
    'tags': ['Symbol'],
    'parameters': [
        {
            'name': 'symbol',
            'in': 'path',
            'type': 'string',
            'required': True,
            'description': 'Symbol name to select.'
        },
        {
            'name': 'body',
            'in': 'body',
            'required': False,
            'schema': {
                'type': 'object',
                'properties': {
                    'enable': {'type': 'boolean', 'default': True}
                }
            }
        }
    ],
    'responses': {
        200: {
            'description': 'Symbol selection status.',
            'schema': {
                'type': 'object',
                'properties': {
                    'message': {'type': 'string'},
                    'symbol': {'type': 'string'},
                    'selected': {'type': 'boolean'}
                }
            }
        },
        400: {
            'description': 'Failed to select symbol.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def symbol_select_endpoint(symbol):
    """
    Select Symbol
    ---
    description: Select/enable a symbol in the Market Watch window.
    """
    try:
        data = request.get_json() or {}
        enable = data.get('enable', True)
        
        result = mt5.symbol_select(symbol, enable)
        
        if not result:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": f"Failed to select symbol {symbol}",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        action = "selected" if enable else "deselected"
        return jsonify({
            "message": f"Symbol {action} successfully",
            "symbol": symbol,
            "selected": result
        }), 200
    
    except Exception as e:
        logger.error(f"Error in symbol_select: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
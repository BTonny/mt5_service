from flask import Blueprint, jsonify, request
import MetaTrader5 as mt5
import logging
from flasgger import swag_from
from datetime import datetime

order_bp = Blueprint('order', __name__)
logger = logging.getLogger(__name__)

@order_bp.route('/order', methods=['POST'])
@swag_from({
    'tags': ['Order'],
    'parameters': [
        {
            'name': 'body',
            'in': 'body',
            'required': True,
            'schema': {
                'type': 'object',
                'properties': {
                    'symbol': {'type': 'string'},
                    'volume': {'type': 'number'},
                    'type': {
                        'type': 'string',
                        'enum': [
                            'BUY', 'SELL',
                            'BUY_LIMIT', 'SELL_LIMIT',
                            'BUY_STOP', 'SELL_STOP',
                            'BUY_STOP_LIMIT', 'SELL_STOP_LIMIT'
                        ]
                    },
                    'price': {'type': 'number'},
                    'deviation': {'type': 'integer', 'default': 20},
                    'magic': {'type': 'integer', 'default': 0},
                    'comment': {'type': 'string', 'default': ''},
                    'type_filling': {
                        'type': 'string',
                        'enum': ['ORDER_FILLING_IOC', 'ORDER_FILLING_FOK', 'ORDER_FILLING_RETURN']
                    },
                    'sl': {'type': 'number'},
                    'tp': {'type': 'number'},
                    'expiration': {'type': 'string', 'format': 'date-time'}
                },
                'required': ['symbol', 'volume', 'type']
            }
        }
    ],
    'responses': {
        200: {
            'description': 'Order executed/placed successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'message': {'type': 'string'},
                    'result': {
                        'type': 'object',
                        'properties': {
                            'retcode': {'type': 'integer'},
                            'order': {'type': 'integer'},
                            'magic': {'type': 'integer'},
                            'price': {'type': 'number'},
                            'symbol': {'type': 'string'}
                        }
                    }
                }
            }
        },
        400: {
            'description': 'Bad request or order failed.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def send_order_endpoint():
    """
    Send Order (Market, Limit, or Stop)
    ---
    description: Execute a market order or place a pending order (limit/stop).
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Order data is required"}), 400

        required_fields = ['symbol', 'volume', 'type']
        if not all(field in data for field in required_fields):
            return jsonify({"error": "Missing required fields"}), 400

        # Map order types to MT5 constants
        order_type_map = {
            'BUY': mt5.ORDER_TYPE_BUY,
            'SELL': mt5.ORDER_TYPE_SELL,
            'BUY_LIMIT': mt5.ORDER_TYPE_BUY_LIMIT,
            'SELL_LIMIT': mt5.ORDER_TYPE_SELL_LIMIT,
            'BUY_STOP': mt5.ORDER_TYPE_BUY_STOP,
            'SELL_STOP': mt5.ORDER_TYPE_SELL_STOP,
            'BUY_STOP_LIMIT': mt5.ORDER_TYPE_BUY_STOP_LIMIT,
            'SELL_STOP_LIMIT': mt5.ORDER_TYPE_SELL_STOP_LIMIT
        }

        order_type_str = data['type']
        if order_type_str not in order_type_map:
            return jsonify({"error": f"Invalid order type: {order_type_str}"}), 400

        mt5_order_type = order_type_map[order_type_str]

        # Determine if this is a market order or pending order
        is_market_order = order_type_str in ['BUY', 'SELL']
        is_pending_order = not is_market_order

        # Map filling type string to MT5 constant
        type_filling_map = {
            'ORDER_FILLING_IOC': mt5.ORDER_FILLING_IOC,
            'ORDER_FILLING_FOK': mt5.ORDER_FILLING_FOK,
            'ORDER_FILLING_RETURN': mt5.ORDER_FILLING_RETURN
        }
        type_filling_str = data.get('type_filling', 'ORDER_FILLING_IOC').upper()
        type_filling = type_filling_map.get(type_filling_str, mt5.ORDER_FILLING_IOC)

        # Build request
        request_data = {
            "action": mt5.TRADE_ACTION_DEAL if is_market_order else mt5.TRADE_ACTION_PENDING,
            "symbol": data['symbol'],
            "volume": float(data['volume']),
            "type": mt5_order_type,
            "deviation": data.get('deviation', 20),
            "magic": data.get('magic', 0),
            "comment": data.get('comment', ''),
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": type_filling,
        }

        # For market orders, get current price
        if is_market_order:
            tick = mt5.symbol_info_tick(data['symbol'])
            if tick is None:
                return jsonify({"error": "Failed to get symbol price"}), 400

            if order_type_str == 'BUY':
                request_data["price"] = tick.ask
            else:  # SELL
                request_data["price"] = tick.bid
        else:
            # For pending orders, price is required
            if 'price' not in data:
                return jsonify({"error": "Price is required for limit/stop orders"}), 400
            request_data["price"] = float(data['price'])

        # Add expiration if provided (for pending orders)
        if 'expiration' in data and is_pending_order:
            try:
                expiration = datetime.fromisoformat(data['expiration'].replace('Z', '+00:00'))
                request_data["expiration"] = expiration
            except ValueError:
                return jsonify({"error": "Invalid expiration format. Use ISO 8601 format"}), 400

        # Add optional SL/TP if provided
        if 'sl' in data:
            request_data["sl"] = float(data['sl'])
        if 'tp' in data:
            request_data["tp"] = float(data['tp'])

        # Send order
        result = mt5.order_send(request_data)
        if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
            error_code, error_str = mt5.last_error()
            error_message = result.comment if result else "MT5 order_send returned None"
            
            return jsonify({
                "error": f"Order failed: {error_message}",
                "mt5_error": error_str,
                "result": result._asdict() if result else None
            }), 400

        action_word = "executed" if is_market_order else "placed"
        return jsonify({
            "message": f"Order {action_word} successfully",
            "result": result._asdict()
        }), 200
    
    except Exception as e:
        logger.error(f"Error in send_order: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@order_bp.route('/cancel_order', methods=['POST'])
@swag_from({
    'tags': ['Order'],
    'parameters': [
        {
            'name': 'body',
            'in': 'body',
            'required': True,
            'schema': {
                'type': 'object',
                'properties': {
                    'order_id': {'type': 'integer'}
                },
                'required': ['order_id']
            }
        }
    ],
    'responses': {
        200: {
            'description': 'Order cancelled successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'message': {'type': 'string'},
                    'result': {
                        'type': 'object',
                        'properties': {
                            'retcode': {'type': 'integer'},
                            'order': {'type': 'integer'},
                            'comment': {'type': 'string'}
                        }
                    }
                }
            }
        },
        400: {
            'description': 'Bad request or failed to cancel order.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def cancel_order_endpoint():
    """
    Cancel Pending Order
    ---
    description: Cancel a pending order (limit, stop, or stop-limit order).
    """
    try:
        data = request.get_json()
        if not data or 'order_id' not in data:
            return jsonify({"error": "Order ID is required"}), 400
        
        order_id = int(data['order_id'])
        
        # Build cancel request
        request_data = {
            "action": mt5.TRADE_ACTION_REMOVE,
            "order": order_id
        }
        
        # Send cancel request
        result = mt5.order_send(request_data)
        
        if result is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to cancel order",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        if result.retcode != mt5.TRADE_RETCODE_DONE:
            return jsonify({
                "error": f"Order cancellation failed: {result.comment}",
                "mt5_error": mt5.last_error()[1],
                "result": result._asdict()
            }), 400
        
        return jsonify({
            "message": "Order cancelled successfully",
            "result": result._asdict()
        }), 200
    
    except ValueError:
        return jsonify({"error": "Invalid order ID format"}), 400
    except Exception as e:
        logger.error(f"Error in cancel_order: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@order_bp.route('/get_orders', methods=['GET'])
@swag_from({
    'tags': ['Order'],
    'parameters': [
        {
            'name': 'magic',
            'in': 'query',
            'type': 'integer',
            'required': False,
            'description': 'Magic number to filter orders.'
        }
    ],
    'responses': {
        200: {
            'description': 'Pending orders retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'orders': {
                        'type': 'array',
                        'items': {'type': 'object'}
                    },
                    'total': {'type': 'integer'}
                }
            }
        },
        400: {
            'description': 'Failed to retrieve orders.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_orders_endpoint():
    """
    Get Pending Orders
    ---
    description: Retrieve all pending orders (limit, stop orders).
    """
    try:
        magic = request.args.get('magic', type=int)
        
        # Get all orders
        if magic is not None:
            orders = mt5.orders_get(magic=magic)
        else:
            orders = mt5.orders_get()
        
        if orders is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to retrieve orders",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        # Convert to list of dictionaries
        orders_list = [order._asdict() for order in orders]
        
        # Convert time fields to ISO format
        for order_dict in orders_list:
            if 'time_setup' in order_dict and order_dict['time_setup'] > 0:
                order_dict['time_setup'] = datetime.fromtimestamp(
                    order_dict['time_setup'], tz=mt5.TIMEZONE
                ).isoformat()
            if 'time_expiration' in order_dict and order_dict['time_expiration'] > 0:
                order_dict['time_expiration'] = datetime.fromtimestamp(
                    order_dict['time_expiration'], tz=mt5.TIMEZONE
                ).isoformat()
            if 'time_done' in order_dict and order_dict['time_done'] > 0:
                order_dict['time_done'] = datetime.fromtimestamp(
                    order_dict['time_done'], tz=mt5.TIMEZONE
                ).isoformat()
        
        return jsonify({
            "orders": orders_list,
            "total": len(orders_list)
        }), 200
    
    except Exception as e:
        logger.error(f"Error in get_orders: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

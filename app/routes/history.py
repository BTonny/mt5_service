from flask import Blueprint, jsonify, request
import MetaTrader5 as mt5
import logging
from datetime import datetime
import pytz
from flasgger import swag_from
from mt5_worker import run_mt5

history_bp = Blueprint('history', __name__)
logger = logging.getLogger(__name__)

@history_bp.route('/get_deal_from_ticket', methods=['GET'])
@swag_from({
    'tags': ['History'],
    'parameters': [
        {
            'name': 'ticket',
            'in': 'query',
            'type': 'integer',
            'required': True,
            'description': 'Ticket number to retrieve deal information.'
        }
    ],
    'responses': {
        200: {
            'description': 'Deal information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'ticket': {'type': 'integer'},
                    'symbol': {'type': 'string'},
                    'type': {'type': 'string'},
                    'volume': {'type': 'number'},
                    'open_time': {'type': 'string', 'format': 'date-time'},
                    'close_time': {'type': 'string', 'format': 'date-time'},
                    'open_price': {'type': 'number'},
                    'close_price': {'type': 'number'},
                    'profit': {'type': 'number'},
                    'commission': {'type': 'number'},
                    'swap': {'type': 'number'},
                    'comment': {'type': 'string'}
                }
            }
        },
        400: {
            'description': 'Invalid ticket format.'
        },
        404: {
            'description': 'Failed to get deal information.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_deal_from_ticket_endpoint():
    """
    Get Deal Information from Ticket
    ---
    description: Retrieve deal information associated with a specific ticket number.
    """
    try:
        ticket = request.args.get('ticket')
        if not ticket:
            return jsonify({"error": "Ticket parameter is required"}), 400
        
        ticket = int(ticket)
        
        # Get deal by ticket
        deals = run_mt5(lambda: mt5.history_deals_get(ticket=ticket))
        if deals is None or len(deals) == 0:
            return jsonify({"error": "Failed to get deal information"}), 404
        
        # Process deal data
        deal = deals[0]
        deal_dict = deal._asdict()
        
        # Convert timestamps to ISO format
        if 'time' in deal_dict and deal_dict['time'] > 0:
            deal_dict['time'] = datetime.fromtimestamp(
                deal_dict['time'], tz=pytz.UTC
            ).isoformat()
        
        return jsonify(deal_dict), 200
    
    except ValueError:
        return jsonify({"error": "Invalid ticket format"}), 400
    except Exception as e:
        logger.error(f"Error in get_deal_from_ticket: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@history_bp.route('/get_order_from_ticket', methods=['GET'])
@swag_from({
    'tags': ['History'],
    'parameters': [
        {
            'name': 'ticket',
            'in': 'query',
            'type': 'integer',
            'required': True,
            'description': 'Ticket number to retrieve order information.'
        }
    ],
    'responses': {
        200: {
            'description': 'Order information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'order': {'type': 'object'}
                    # Define properties based on order structure
                }
            }
        },
        400: {
            'description': 'Invalid ticket format.'
        },
        404: {
            'description': 'Failed to get order information.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_order_from_ticket_endpoint():
    """
    Get Order Information from Ticket
    ---
    description: Retrieve order information associated with a specific ticket number.
    """
    try:
        ticket = request.args.get('ticket')
        if not ticket:
            return jsonify({"error": "Ticket parameter is required"}), 400
        
        ticket = int(ticket)
        
        # Get order by ticket
        orders = run_mt5(lambda: mt5.history_orders_get(ticket=ticket))
        if orders is None or len(orders) == 0:
            return jsonify({"error": "Failed to get order information"}), 404
        
        # Process order data
        order = orders[0]
        order_dict = order._asdict()
        
        # Convert timestamps to ISO format
        if 'time_setup' in order_dict and order_dict['time_setup'] > 0:
            order_dict['time_setup'] = datetime.fromtimestamp(
                order_dict['time_setup'], tz=pytz.UTC
            ).isoformat()
        if 'time_expiration' in order_dict and order_dict['time_expiration'] > 0:
            order_dict['time_expiration'] = datetime.fromtimestamp(
                order_dict['time_expiration'], tz=pytz.UTC
            ).isoformat()
        if 'time_done' in order_dict and order_dict['time_done'] > 0:
            order_dict['time_done'] = datetime.fromtimestamp(
                order_dict['time_done'], tz=pytz.UTC
            ).isoformat()
        
        return jsonify(order_dict), 200
    
    except ValueError:
        return jsonify({"error": "Invalid ticket format"}), 400
    except Exception as e:
        logger.error(f"Error in get_order_from_ticket: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@history_bp.route('/history_deals_get', methods=['GET'])
@swag_from({
    'tags': ['History'],
    'parameters': [
        {
            'name': 'from_date',
            'in': 'query',
            'type': 'string',
            'required': True,
            'format': 'date-time',
            'description': 'Start date in ISO format.'
        },
        {
            'name': 'to_date',
            'in': 'query',
            'type': 'string',
            'required': True,
            'format': 'date-time',
            'description': 'End date in ISO format.'
        },
        {
            'name': 'position',
            'in': 'query',
            'type': 'integer',
            'required': False,
            'description': 'Position ID to filter deals.'
        }
    ],
    'responses': {
        200: {
            'description': 'Deals history retrieved successfully.',
            'schema': {
                'type': 'array',
                'items': {
                    'type': 'object'
                    # Define properties based on deal structure
                }
            }
        },
        400: {
            'description': 'Invalid parameter format or missing parameters.'
        },
        404: {
            'description': 'Failed to get deals history.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def history_deals_get_endpoint():
    """
    Get Deals History
    ---
    description: Retrieve historical deals within a specified date range, optionally filtered by position.
    """
    try:
        from_date = request.args.get('from_date')
        to_date = request.args.get('to_date')
        position = request.args.get('position')
        
        if not all([from_date, to_date]):
            return jsonify({"error": "from_date and to_date parameters are required"}), 400
        
        # Parse dates and ensure timezone awareness
        try:
            from_date_parsed = datetime.fromisoformat(from_date.replace('Z', '+00:00'))
            to_date_parsed = datetime.fromisoformat(to_date.replace('Z', '+00:00'))
            
            # Ensure timezone-aware (if naive, assume UTC)
            if from_date_parsed.tzinfo is None:
                from_date_parsed = pytz.UTC.localize(from_date_parsed)
            if to_date_parsed.tzinfo is None:
                to_date_parsed = pytz.UTC.localize(to_date_parsed)
            
            from_timestamp = int(from_date_parsed.timestamp())
            to_timestamp = int(to_date_parsed.timestamp())
        except ValueError as ve:
            return jsonify({"error": f"Invalid date format: {str(ve)}"}), 400
        
        # Get deals with optional position filter
        if position:
            position = int(position)
            deals = run_mt5(lambda: mt5.history_deals_get(from_timestamp, to_timestamp, position=position))
        else:
            deals = run_mt5(lambda: mt5.history_deals_get(from_timestamp, to_timestamp))
        
        if deals is None:
            return jsonify({"error": "Failed to get deals history"}), 404
        
        # Convert to list of dictionaries
        deals_list = [deal._asdict() for deal in deals]
        
        # Convert timestamps to ISO format
        for deal_dict in deals_list:
            if 'time' in deal_dict and deal_dict['time'] > 0:
                deal_dict['time'] = datetime.fromtimestamp(
                    deal_dict['time'], tz=pytz.UTC
                ).isoformat()
        
        return jsonify({
            "deals": deals_list,
            "total": len(deals_list)
        }), 200
    
    except ValueError:
        return jsonify({"error": "Invalid parameter format"}), 400
    except Exception as e:
        logger.error(f"Error in history_deals_get: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@history_bp.route('/history_orders_get', methods=['GET'])
@swag_from({
    'tags': ['History'],
    'parameters': [
        {
            'name': 'ticket',
            'in': 'query',
            'type': 'integer',
            'required': False,
            'description': 'Ticket number to retrieve orders history.'
        }
    ],
    'responses': {
        200: {
            'description': 'Orders history retrieved successfully.',
            'schema': {
                'type': 'array',
                'items': {
                    'type': 'object'
                    # Define properties based on order structure
                }
            }
        },
        400: {
            'description': 'Invalid ticket format or missing parameter.'
        },
        404: {
            'description': 'Failed to get orders history.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def history_orders_get_endpoint():
    """
    Get Orders History
    ---
    description: Retrieve historical orders, optionally filtered by ticket.
    """
    try:
        ticket = request.args.get('ticket', type=int)
        
        # Get orders with optional ticket filter
        if ticket:
            orders = run_mt5(lambda: mt5.history_orders_get(ticket=ticket))
        else:
            orders = run_mt5(lambda: mt5.history_orders_get())
        
        if orders is None:
            return jsonify({"error": "Failed to get orders history"}), 404
        
        # Convert to list of dictionaries
        orders_list = [order._asdict() for order in orders]
        
        # Convert timestamps to ISO format
        for order_dict in orders_list:
            if 'time_setup' in order_dict and order_dict['time_setup'] > 0:
                order_dict['time_setup'] = datetime.fromtimestamp(
                    order_dict['time_setup'], tz=pytz.UTC
                ).isoformat()
            if 'time_expiration' in order_dict and order_dict['time_expiration'] > 0:
                order_dict['time_expiration'] = datetime.fromtimestamp(
                    order_dict['time_expiration'], tz=pytz.UTC
                ).isoformat()
            if 'time_done' in order_dict and order_dict['time_done'] > 0:
                order_dict['time_done'] = datetime.fromtimestamp(
                    order_dict['time_done'], tz=pytz.UTC
                ).isoformat()
        
        return jsonify({
            "orders": orders_list,
            "total": len(orders_list)
        }), 200
    
    except ValueError:
        return jsonify({"error": "Invalid ticket format"}), 400
    except Exception as e:
        logger.error(f"Error in history_orders_get: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const { body, validationResult } = require('express-validator');
const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');

const app = express();
const PORT = process.env.PORT || 5000;

// ─── MIDDLEWARE ───────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ─── MONGODB CONNECTION ───────────────────────────────────────────────────────
const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://mongo:27017/myfoodmylife');
    console.log('✅ MongoDB connected');
  } catch (err) {
    console.error('❌ MongoDB connection error:', err.message);
    process.exit(1);
  }
};

// ─── ORDER SCHEMA ─────────────────────────────────────────────────────────────
const orderItemSchema = new mongoose.Schema({
  id:    { type: Number, required: true },
  name:  { type: String, required: true },
  qty:   { type: Number, required: true, min: 1 },
  price: { type: Number, required: true },
});

const orderSchema = new mongoose.Schema({
  orderId: {
    type: String,
    default: () => 'ORD-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
    unique: true,
  },
  customer: {
    name:    { type: String, required: true, trim: true },
    phone:   { type: String, required: true, trim: true },
    address: { type: String, required: true, trim: true },
  },
  items:  { type: [orderItemSchema], required: true },
  total:  { type: Number, required: true },
  status: {
    type: String,
    enum: ['received', 'preparing', 'out_for_delivery', 'delivered'],
    default: 'received',
  },
  snsNotified: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },
});

const Order = mongoose.model('Order', orderSchema);

// ─── AWS SNS CLIENT ───────────────────────────────────────────────────────────
const snsClient = new SNSClient({
  region: process.env.AWS_REGION || 'ap-south-1',
  credentials: {
    accessKeyId:     process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

// ─── SNS NOTIFICATION ─────────────────────────────────────────────────────────
const sendOrderNotification = async (order) => {
  const itemsList = order.items
    .map(i => `  • ${i.name} x${i.qty} = ₹${i.price * i.qty}`)
    .join('\n');

  const message = `
🍖 NEW ORDER — My Food My Life
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Order ID  : ${order.orderId}
📅 Date/Time : ${new Date(order.createdAt).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })}

👤 CUSTOMER DETAILS
  Name    : ${order.customer.name}
  Phone   : ${order.customer.phone}
  Address : ${order.customer.address}

🍽️  ORDER ITEMS
${itemsList}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💰 TOTAL AMOUNT : ₹${order.total}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Please prepare the order and arrange delivery. 🚀
  `.trim();

  const params = {
    TopicArn: process.env.AWS_SNS_TOPIC_ARN,
    Subject:  `🍖 New Order #${order.orderId} — ₹${order.total}`,
    Message:  message,
  };

  const command = new PublishCommand(params);
  const response = await snsClient.send(command);
  console.log('📧 SNS notification sent. MessageId:', response.MessageId);
  return response;
};

// ─── ROUTES ───────────────────────────────────────────────────────────────────

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', service: 'My Food My Life API', timestamp: new Date() });
});

// Place a new order
app.post(
  '/api/orders',
  [
    body('customer.name').notEmpty().withMessage('Name is required').trim(),
    body('customer.phone')
      .matches(/^\d{10}$/)
      .withMessage('Phone must be a 10-digit number'),
    body('customer.address').notEmpty().withMessage('Address is required').trim(),
    body('items').isArray({ min: 1 }).withMessage('At least one item is required'),
    body('items.*.name').notEmpty().withMessage('Item name is required'),
    body('items.*.qty').isInt({ min: 1 }).withMessage('Quantity must be at least 1'),
    body('items.*.price').isNumeric().withMessage('Price must be a number'),
    body('total').isNumeric().withMessage('Total must be a number'),
  ],
  async (req, res) => {
    // Validate inputs
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    try {
      const { customer, items, total } = req.body;

      // Save order to MongoDB
      const order = new Order({ customer, items, total });
      await order.save();
      console.log(`✅ Order saved: ${order.orderId}`);

      // Send SNS notification (non-blocking — don't fail if SNS errors)
      try {
        await sendOrderNotification(order);
        order.snsNotified = true;
        await order.save();
      } catch (snsErr) {
        console.error('⚠️  SNS notification failed (order still saved):', snsErr.message);
      }

      return res.status(201).json({
        success: true,
        message: 'Order placed successfully!',
        orderId: order.orderId,
      });
    } catch (err) {
      console.error('❌ Order creation error:', err.message);
      return res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
);

// Get all orders (admin view)
app.get('/api/orders', async (req, res) => {
  try {
    const orders = await Order.find().sort({ createdAt: -1 }).limit(50);
    res.json({ success: true, count: orders.length, orders });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to fetch orders' });
  }
});

// Get single order by ID
app.get('/api/orders/:orderId', async (req, res) => {
  try {
    const order = await Order.findOne({ orderId: req.params.orderId });
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    res.json({ success: true, order });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to fetch order' });
  }
});

// Update order status
app.patch('/api/orders/:orderId/status', async (req, res) => {
  const { status } = req.body;
  const validStatuses = ['received', 'preparing', 'out_for_delivery', 'delivered'];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ success: false, message: 'Invalid status value' });
  }
  try {
    const order = await Order.findOneAndUpdate(
      { orderId: req.params.orderId },
      { status },
      { new: true }
    );
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    res.json({ success: true, order });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to update status' });
  }
});

// ─── START SERVER ─────────────────────────────────────────────────────────────
connectDB().then(() => {
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📡 AWS Region: ${process.env.AWS_REGION}`);
    console.log(`📬 SNS Topic: ${process.env.AWS_SNS_TOPIC_ARN}`);
  });
});
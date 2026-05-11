import React, { useState, useRef, useEffect } from 'react';
import {
  ArrowLeft, X, Phone, Truck, Camera, ImageIcon, Send, AlertTriangle,
  Check, CreditCard, Calendar, Clock, Bell
} from 'lucide-react';

const MECHANIC_IMG = "https://images.unsplash.com/photo-1615906655593-ad0386982a0f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtYWxlJTIwbWVjaGFuaWMlMjBwb3J0cmFpdCUyMHByb2Zlc3Npb25hbHxlbnwxfHx8fDE3NzI5MTk3NjB8MA&ixlib=rb-4.1.0&q=80&w=400";

// ─── Chat / Messaging System ──────────────────────────────────────────────────────
const SAMPLE_MESSAGES = [
  { id: 1, sender: 'mechanic', text: 'On my way now, should be there in 15 min', time: '14:23', read: true },
  { id: 2, sender: 'fleet', text: 'Great, driver will wait by the layby', time: '14:24', read: true },
  { id: 3, sender: 'mechanic', text: 'Can you send a photo of the tyre damage?', time: '14:25', read: true },
  { id: 4, sender: 'fleet', text: '', time: '14:26', read: true, image: 'https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?w=600' },
  { id: 5, sender: 'mechanic', text: 'Perfect, I can see it\'s the inner tyre. Bringing the right size.', time: '14:27', read: false },
];

export function ChatScreen({ job, onClose, mechanicName = "Deon van Wyk", role = "fleet" }: any) {
  const [messages, setMessages] = useState(SAMPLE_MESSAGES);
  const [input, setInput] = useState('');
  const [showImagePicker, setShowImagePicker] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const sendMessage = () => {
    if (!input.trim()) return;
    const newMsg = {
      id: messages.length + 1,
      sender: role,
      text: input,
      time: new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }),
      read: false,
    };
    setMessages([...messages, newMsg]);
    setInput('');
  };

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (ev) => {
      if (ev.target?.result) {
        const newMsg = {
          id: messages.length + 1,
          sender: role,
          text: '',
          time: new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }),
          read: false,
          image: ev.target.result as string,
        };
        setMessages([...messages, newMsg]);
      }
    };
    reader.readAsDataURL(file);
    e.target.value = '';
    setShowImagePicker(false);
  };

  const otherPersonName = role === 'fleet' ? mechanicName : job?.fleetName || 'Fleet Operator';

  return (
    <div className="absolute inset-0 bg-[#080808] z-[100] flex flex-col">
      {/* Header */}
      <div className="px-4 pt-4 pb-3 border-b border-[#1a1a1a] flex items-center gap-3 flex-shrink-0">
        <button onClick={onClose} className="w-8 h-8 bg-[#1a1a1a] rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-3.5 h-3.5 text-gray-400" />
        </button>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <img src={MECHANIC_IMG} className="w-8 h-8 rounded-lg object-cover" />
            <div className="min-w-0 flex-1">
              <p className="text-white font-bold text-sm truncate">{otherPersonName}</p>
              <p className="text-gray-600 text-[10px]">Online now</p>
            </div>
          </div>
        </div>
        <button className="w-8 h-8 bg-[#1a1a1a] rounded-xl flex items-center justify-center">
          <Phone className="w-3.5 h-3.5 text-yellow-400" />
        </button>
      </div>

      {/* Job context banner */}
      <div className="px-4 py-2 bg-[#0f0f0f] border-b border-[#1a1a1a] flex-shrink-0">
        <div className="flex items-center gap-2 text-[10px]">
          <Truck className="w-3 h-3 text-yellow-400" />
          <span className="text-gray-500">{job?.id || 'TF-8821'}</span>
          <span className="text-gray-700">·</span>
          <span className="text-gray-400 truncate">{job?.truck || 'Vehicle details'}</span>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3" style={{ scrollbarWidth: 'none' }}>
        {messages.map(msg => (
          <div key={msg.id} className={`flex ${msg.sender === role ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[75%] ${msg.sender === role ? 'bg-yellow-400' : 'bg-[#1a1a1a]'} rounded-2xl p-3`}>
              {msg.image ? (
                <img src={msg.image} className="w-full rounded-lg" alt="Shared image" />
              ) : (
                <p className={`text-sm ${msg.sender === role ? 'text-black font-medium' : 'text-white'}`}>{msg.text}</p>
              )}
              <p className={`text-[9px] mt-1 ${msg.sender === role ? 'text-black/60' : 'text-gray-600'}`}>{msg.time}</p>
            </div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Image picker popup */}
      {showImagePicker && (
        <div className="absolute inset-x-0 bottom-16 mx-4 mb-2 bg-[#1a1a1a] rounded-xl border border-[#2a2a2a] overflow-hidden">
          <button
            onClick={() => {
              if (fileInputRef.current) {
                fileInputRef.current.setAttribute('capture', 'environment');
                fileInputRef.current.click();
                setShowImagePicker(false);
              }
            }}
            className="w-full px-4 py-3 flex items-center gap-3 border-b border-[#2a2a2a] active:bg-[#222]"
          >
            <Camera className="w-4 h-4 text-yellow-400" />
            <span className="text-white text-sm">Take Photo</span>
          </button>
          <button
            onClick={() => {
              if (fileInputRef.current) {
                fileInputRef.current.removeAttribute('capture');
                fileInputRef.current.click();
                setShowImagePicker(false);
              }
            }}
            className="w-full px-4 py-3 flex items-center gap-3 active:bg-[#222]"
          >
            <ImageIcon className="w-4 h-4 text-yellow-400" />
            <span className="text-white text-sm">Choose from Gallery</span>
          </button>
        </div>
      )}

      {/* Input */}
      <div className="px-4 py-3 border-t border-[#1a1a1a] flex items-center gap-2 flex-shrink-0 bg-[#080808]">
        <input
          type="file"
          ref={fileInputRef}
          onChange={handleImageUpload}
          accept="image/*"
          className="hidden"
        />
        <button
          onClick={() => setShowImagePicker(!showImagePicker)}
          className="w-9 h-9 bg-[#1a1a1a] rounded-xl flex items-center justify-center flex-shrink-0"
        >
          <Camera className="w-4 h-4 text-gray-400" />
        </button>
        <input
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && sendMessage()}
          placeholder="Type a message..."
          className="flex-1 bg-[#1a1a1a] border border-[#2a2a2a] rounded-xl px-4 py-2.5 text-white text-sm placeholder:text-gray-700 focus:outline-none focus:border-yellow-400/60"
        />
        <button
          onClick={sendMessage}
          disabled={!input.trim()}
          className="w-9 h-9 bg-yellow-400 rounded-xl flex items-center justify-center flex-shrink-0 disabled:opacity-30 active:scale-95 transition-transform"
        >
          <Send className="w-4 h-4 text-black" />
        </button>
      </div>
    </div>
  );
}

// ─── Job Cancellation Flow ────────────────────────────────────────────────────────
const CANCELLATION_REASONS = [
  { id: 'resolved', label: 'Issue resolved on its own', icon: '✅' },
  { id: 'found-other', label: 'Found another mechanic', icon: '🔧' },
  { id: 'no-longer-needed', label: 'Repair no longer needed', icon: '🚫' },
  { id: 'too-expensive', label: 'Quotes too expensive', icon: '💷' },
  { id: 'other', label: 'Other reason', icon: '📝' },
];

export function CancelJobSheet({ job, mechanicEnRoute, onClose, onConfirm }: any) {
  const [selectedReason, setSelectedReason] = useState<string | null>(null);
  const [otherText, setOtherText] = useState('');
  const [confirmed, setConfirmed] = useState(false);

  const total = typeof job?.total === 'number' ? job.total : parseFloat(String(job?.total || '145').replace('£', ''));
  const fee = mechanicEnRoute ? total * 0.1 : 0;
  const canProceed = selectedReason && (selectedReason !== 'other' || otherText.trim());

  const handleConfirm = () => {
    if (!canProceed) return;
    setConfirmed(true);
    setTimeout(() => {
      onConfirm();
      onClose();
    }, 1500);
  };

  if (confirmed) {
    return (
      <div className="absolute inset-0 bg-black/90 z-50 flex items-center justify-center px-6" onClick={onClose}>
        <div className="bg-[#0e0e0e] rounded-2xl p-6 text-center max-w-sm" onClick={e => e.stopPropagation()}>
          <div className="w-16 h-16 bg-green-500/10 border-2 border-green-500 rounded-full flex items-center justify-center mx-auto mb-4">
            <Check className="w-8 h-8 text-green-500" />
          </div>
          <p className="text-white font-black text-lg mb-2">Job Cancelled</p>
          <p className="text-gray-500 text-sm">
            {mechanicEnRoute ? `Cancellation fee of £${fee.toFixed(2)} will be charged.` : 'No cancellation fee applied.'}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="absolute inset-0 bg-black/85 z-50 flex flex-col justify-end" onClick={onClose}>
      <div className="bg-[#0e0e0e] rounded-t-3xl border-t border-[#2a2a2a] flex flex-col max-h-[85%]" onClick={e => e.stopPropagation()}>
        <div className="flex justify-center pt-3 pb-1 flex-shrink-0">
          <div className="w-10 h-1 bg-[#333] rounded-full" />
        </div>

        <div className="px-5 pt-2 pb-3 border-b border-[#1a1a1a] flex items-center justify-between flex-shrink-0">
          <div>
            <p className="text-white font-black text-lg">Cancel Job?</p>
            <p className="text-gray-600 text-[11px] mt-0.5">{job?.id || 'TF-8821'} · {job?.truck || 'Vehicle'}</p>
          </div>
          <button onClick={onClose} className="w-8 h-8 bg-[#1a1a1a] rounded-xl flex items-center justify-center">
            <X className="w-3.5 h-3.5 text-gray-500" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4" style={{ scrollbarWidth: 'none' }}>
          {/* Policy Warning */}
          <div className={`p-4 rounded-xl border ${mechanicEnRoute ? 'bg-red-500/10 border-red-500/30' : 'bg-green-500/10 border-green-500/30'}`}>
            <div className="flex items-start gap-3">
              <AlertTriangle className={`w-5 h-5 flex-shrink-0 mt-0.5 ${mechanicEnRoute ? 'text-red-400' : 'text-green-400'}`} />
              <div>
                <p className={`font-bold text-sm mb-1 ${mechanicEnRoute ? 'text-red-400' : 'text-green-400'}`}>
                  {mechanicEnRoute ? 'Cancellation Fee Applies' : 'Free Cancellation'}
                </p>
                <p className="text-gray-400 text-xs leading-relaxed">
                  {mechanicEnRoute
                    ? `Mechanic is already en route. A 10% cancellation fee (£${fee.toFixed(2)}) will be charged to your card.`
                    : 'Mechanic has not started journey yet. You can cancel for free with no charges.'}
                </p>
              </div>
            </div>
          </div>

          {/* Reason Selection */}
          <div>
            <label className="text-gray-500 text-[11px] uppercase tracking-widest font-semibold block mb-2">
              Reason for Cancellation
            </label>
            <div className="space-y-2">
              {CANCELLATION_REASONS.map(reason => (
                <button
                  key={reason.id}
                  onClick={() => setSelectedReason(reason.id)}
                  className={`w-full p-3 rounded-xl border flex items-center gap-3 transition-all ${
                    selectedReason === reason.id
                      ? 'border-yellow-400 bg-yellow-400/10'
                      : 'border-[#2a2a2a] bg-[#0f0f0f]'
                  }`}
                >
                  <span className="text-xl">{reason.icon}</span>
                  <span className={`text-sm flex-1 text-left ${selectedReason === reason.id ? 'text-white font-semibold' : 'text-gray-400'}`}>
                    {reason.label}
                  </span>
                  {selectedReason === reason.id && <Check className="w-4 h-4 text-yellow-400" />}
                </button>
              ))}
            </div>
          </div>

          {/* Other reason text */}
          {selectedReason === 'other' && (
            <div>
              <label className="text-gray-500 text-[11px] uppercase tracking-widest font-semibold block mb-2">
                Please specify
              </label>
              <textarea
                value={otherText}
                onChange={e => setOtherText(e.target.value)}
                placeholder="Briefly explain your reason..."
                rows={3}
                className="w-full bg-[#111] border border-[#2a2a2a] rounded-xl px-4 py-3 text-white text-sm placeholder:text-gray-700 focus:outline-none focus:border-yellow-400/60 resize-none"
              />
            </div>
          )}
        </div>

        {/* Actions */}
        <div className="px-5 py-4 border-t border-[#1a1a1a] space-y-2 flex-shrink-0">
          <button
            onClick={handleConfirm}
            disabled={!canProceed}
            className="w-full bg-red-500 text-white py-4 rounded-xl font-black text-sm tracking-widest uppercase active:scale-[0.98] transition-transform disabled:opacity-30"
          >
            {mechanicEnRoute ? `Cancel Job (Pay £${fee.toFixed(2)} Fee)` : 'Cancel Job (Free)'}
          </button>
          <button
            onClick={onClose}
            className="w-full bg-[#1a1a1a] text-gray-400 py-4 rounded-xl font-bold text-sm tracking-wide uppercase active:scale-[0.98] transition-transform"
          >
            Keep Job Active
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Notifications Center ─────────────────────────────────────────────────────────
const NOTIFICATIONS = [
  { id: 1, type: 'quote', title: 'New Quote Received', message: 'Deon van Wyk quoted £145 for TF-8821', time: '2 min ago', unread: true, icon: '💷' },
  { id: 2, type: 'accepted', title: 'Quote Accepted', message: 'You accepted the quote. Waiting for mechanic to start journey', time: '1 hr ago', unread: true, icon: '✅' },
  { id: 3, type: 'enroute', title: 'Mechanic Started Journey', message: 'Deon is on the way to your vehicle, ETA 15 min', time: '1 hr ago', unread: false, icon: '🚗' },
  { id: 4, type: 'complete', title: 'Job Completed', message: 'Please approve completion for TF-8801', time: '2 hrs ago', unread: false, icon: '✅' },
  { id: 5, type: 'payment', title: 'Payment Processed', message: '£145.00 charged to card ending 4242', time: '3 hrs ago', unread: false, icon: '💳' },
  { id: 6, type: 'review', title: 'Review Reminder', message: 'Rate your experience with Sipho Molefe', time: '5 hrs ago', unread: false, icon: '⭐' },
];

export function NotificationsScreen({ onClose }: any) {
  const [notifications, setNotifications] = useState(NOTIFICATIONS);
  const unreadCount = notifications.filter(n => n.unread).length;

  const markAllRead = () => {
    setNotifications(notifications.map(n => ({ ...n, unread: false })));
  };

  return (
    <div className="h-full bg-[#080808] flex flex-col">
      {/* Header */}
      <div className="px-4 pt-4 pb-3 border-b border-[#1a1a1a] flex items-center justify-between flex-shrink-0">
        <div className="flex items-center gap-3">
          <button onClick={onClose} className="w-8 h-8 bg-[#1a1a1a] rounded-xl flex items-center justify-center">
            <ArrowLeft className="w-3.5 h-3.5 text-gray-400" />
          </button>
          <div>
            <p className="text-white font-black text-lg">Notifications</p>
            {unreadCount > 0 && (
              <p className="text-yellow-400 text-[10px] font-semibold">{unreadCount} unread</p>
            )}
          </div>
        </div>
        {unreadCount > 0 && (
          <button
            onClick={markAllRead}
            className="text-yellow-400 text-xs font-bold uppercase tracking-wide"
          >
            Mark all read
          </button>
        )}
      </div>

      {/* Notifications list */}
      <div className="flex-1 overflow-y-auto" style={{ scrollbarWidth: 'none' }}>
        {notifications.map(notif => (
          <div
            key={notif.id}
            className={`px-4 py-4 border-b border-[#1a1a1a] flex items-start gap-3 ${notif.unread ? 'bg-yellow-400/5' : ''}`}
          >
            <div className="text-2xl flex-shrink-0">{notif.icon}</div>
            <div className="flex-1 min-w-0">
              <div className="flex items-start justify-between gap-2 mb-1">
                <p className="text-white font-bold text-sm">{notif.title}</p>
                {notif.unread && <div className="w-2 h-2 bg-yellow-400 rounded-full flex-shrink-0 mt-1" />}
              </div>
              <p className="text-gray-400 text-xs leading-relaxed mb-1">{notif.message}</p>
              <p className="text-gray-700 text-[10px]">{notif.time}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Payment Methods Management ───────────────────────────────────────────────────
const SAVED_CARDS = [
  { id: 1, type: 'Visa', last4: '4242', expiry: '12/26', isDefault: true },
  { id: 2, type: 'Mastercard', last4: '8888', expiry: '09/25', isDefault: false },
];

function Input({ label, placeholder, type = 'text', value, onChange }: any) {
  return (
    <div className="space-y-1.5">
      {label && <label className="text-[11px] text-gray-500 uppercase tracking-widest font-semibold">{label}</label>}
      <input type={type} placeholder={placeholder} value={value} onChange={onChange} className="w-full bg-[#111] border border-[#2a2a2a] rounded-xl px-4 py-3 text-white placeholder:text-gray-700 focus:outline-none focus:border-yellow-400/60 text-sm" />
    </div>
  );
}

export function PaymentMethodsScreen({ onClose }: any) {
  const [cards, setCards] = useState(SAVED_CARDS);
  const [showAddCard, setShowAddCard] = useState(false);
  const [cardNumber, setCardNumber] = useState('');
  const [expiry, setExpiry] = useState('');
  const [cvc, setCvc] = useState('');
  const [cardholderName, setCardholderName] = useState('');

  const setDefault = (id: number) => {
    setCards(cards.map(c => ({ ...c, isDefault: c.id === id })));
  };

  const removeCard = (id: number) => {
    setCards(cards.filter(c => c.id !== id));
  };

  const saveCard = () => {
    if (!cardNumber || !expiry || !cvc || !cardholderName) return;
    
    // Extract last 4 digits
    const last4 = cardNumber.replace(/\s/g, '').slice(-4);
    
    // Detect card type (simple detection)
    const firstDigit = cardNumber.replace(/\s/g, '')[0];
    let type = 'Visa';
    if (firstDigit === '5') type = 'Mastercard';
    else if (firstDigit === '3') type = 'Amex';
    
    const newCard = {
      id: cards.length + 1,
      type,
      last4,
      expiry,
      isDefault: cards.length === 0, // First card is default
    };
    
    setCards([...cards, newCard]);
    
    // Reset form
    setCardNumber('');
    setExpiry('');
    setCvc('');
    setCardholderName('');
    setShowAddCard(false);
  };

  return (
    <div className="h-full bg-[#080808] flex flex-col">
      {/* Header */}
      <div className="px-4 pt-4 pb-3 border-b border-[#1a1a1a] flex items-center justify-between flex-shrink-0">
        <div className="flex items-center gap-3">
          <button onClick={onClose} className="w-8 h-8 bg-[#1a1a1a] rounded-xl flex items-center justify-center">
            <ArrowLeft className="w-3.5 h-3.5 text-gray-400" />
          </button>
          <p className="text-white font-black text-lg">Payment Methods</p>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3" style={{ scrollbarWidth: 'none' }}>
        {/* Cards list */}
        {cards.map(card => (
          <div key={card.id} className="bg-[#0f0f0f] border border-[#2a2a2a] rounded-xl p-4">
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-gradient-to-br from-yellow-400 to-yellow-600 rounded-lg flex items-center justify-center">
                  <CreditCard className="w-6 h-6 text-black" />
                </div>
                <div>
                  <p className="text-white font-bold text-sm">{card.type} •••• {card.last4}</p>
                  <p className="text-gray-600 text-xs">Expires {card.expiry}</p>
                </div>
              </div>
              {card.isDefault && (
                <div className="px-2 py-1 bg-yellow-400/10 border border-yellow-400/30 rounded-md">
                  <p className="text-yellow-400 text-[9px] font-bold uppercase tracking-wide">Default</p>
                </div>
              )}
            </div>
            <div className="flex gap-2">
              {!card.isDefault && (
                <button
                  onClick={() => setDefault(card.id)}
                  className="flex-1 py-2 bg-[#1a1a1a] text-gray-400 rounded-lg text-xs font-bold uppercase tracking-wide active:scale-95 transition-transform"
                >
                  Set Default
                </button>
              )}
              <button
                onClick={() => removeCard(card.id)}
                className="flex-1 py-2 bg-red-500/10 text-red-400 rounded-lg text-xs font-bold uppercase tracking-wide active:scale-95 transition-transform border border-red-500/30"
              >
                Remove
              </button>
            </div>
          </div>
        ))}

        {/* Add card button */}
        <button
          onClick={() => setShowAddCard(!showAddCard)}
          className="w-full py-4 bg-[#1a1a1a] border-2 border-dashed border-[#2a2a2a] rounded-xl text-gray-500 font-bold text-sm uppercase tracking-wide flex items-center justify-center gap-2 active:scale-95 transition-transform"
        >
          <span className="text-lg">+</span>
          Add New Card
        </button>

        {/* Add card form */}
        {showAddCard && (
          <div className="bg-[#0f0f0f] border border-yellow-400/30 rounded-xl p-4 space-y-3">
            <p className="text-yellow-400 text-xs font-bold uppercase tracking-wide">New Card Details</p>
            <Input label="Card Number" placeholder="1234 5678 9012 3456" value={cardNumber} onChange={e => setCardNumber(e.target.value)} />
            <div className="grid grid-cols-2 gap-3">
              <Input label="Expiry" placeholder="MM/YY" value={expiry} onChange={e => setExpiry(e.target.value)} />
              <Input label="CVC" placeholder="123" value={cvc} onChange={e => setCvc(e.target.value)} />
            </div>
            <Input label="Cardholder Name" placeholder="John Smith" value={cardholderName} onChange={e => setCardholderName(e.target.value)} />
            <button className="w-full bg-yellow-400 text-black py-3 rounded-xl font-black text-sm tracking-widest uppercase active:scale-[0.98] transition-transform" onClick={saveCard}>
              Save Card
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Vehicle Fleet Management ─────────────────────────────────────────────────────
const FLEET_VEHICLES = [
  { id: 1, reg: 'CA 456-789', make: 'MAN', model: 'TGX 18.640', type: 'Tautliner', vin: 'WMA06XZZ4FM123456', mileage: '245,000 km', lastService: '15 Jan 2025' },
  { id: 2, reg: 'GP 331-876', make: 'Mercedes-Benz', model: 'Actros 2545', type: 'Rigid 8T', vin: 'WDB9340341L789012', mileage: '189,500 km', lastService: '3 Feb 2025' },
  { id: 3, reg: 'KZN 44-221', make: 'Volvo', model: 'FH16 750', type: 'Tanker', vin: 'YV2A20A61GA456789', mileage: '312,800 km', lastService: '28 Dec 2024' },
];

export function VehicleFleetScreen({ onClose, onSelectVehicle }: any) {
  const [vehicles, setVehicles] = useState(FLEET_VEHICLES);
  const [showAddVehicle, setShowAddVehicle] = useState(false);

  return (
    <div className="h-full bg-[#080808] flex flex-col">
      {/* Header */}
      <div className="px-4 pt-4 pb-3 border-b border-[#1a1a1a] flex items-center justify-between flex-shrink-0">
        <div className="flex items-center gap-3">
          <button onClick={onClose} className="w-8 h-8 bg-[#1a1a1a] rounded-xl flex items-center justify-center">
            <ArrowLeft className="w-3.5 h-3.5 text-gray-400" />
          </button>
          <p className="text-white font-black text-lg">My Fleet</p>
        </div>
        <button
          onClick={() => setShowAddVehicle(true)}
          className="px-3 py-2 bg-yellow-400 text-black rounded-lg text-xs font-black uppercase tracking-wide flex items-center gap-1"
        >
          <span>+</span> Add
        </button>
      </div>

      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3" style={{ scrollbarWidth: 'none' }}>
        {vehicles.map(vehicle => (
          <div
            key={vehicle.id}
            onClick={() => onSelectVehicle?.(vehicle)}
            className="bg-[#0f0f0f] border border-[#2a2a2a] rounded-xl p-4 active:scale-95 transition-transform"
          >
            <div className="flex items-start justify-between mb-3">
              <div>
                <p className="text-white font-black text-base mb-1">{vehicle.reg}</p>
                <p className="text-gray-400 text-xs">{vehicle.make} {vehicle.model}</p>
              </div>
              <div className="px-2 py-1 bg-yellow-400/10 border border-yellow-400/30 rounded-md">
                <p className="text-yellow-400 text-[9px] font-bold uppercase tracking-wide">{vehicle.type}</p>
              </div>
            </div>
            <div className="space-y-1.5 text-xs">
              <div className="flex justify-between">
                <span className="text-gray-600">Last Service</span>
                <span className="text-gray-400">{vehicle.lastService}</span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Add Vehicle Sheet */}
      {showAddVehicle && (
        <div className="absolute inset-0 bg-black/85 z-50 flex flex-col justify-end" onClick={() => setShowAddVehicle(false)}>
          <div className="bg-[#0e0e0e] rounded-t-3xl border-t border-[#2a2a2a] flex flex-col max-h-[85%]" onClick={e => e.stopPropagation()}>
            <div className="flex justify-center pt-3 pb-1 flex-shrink-0">
              <div className="w-10 h-1 bg-[#333] rounded-full" />
            </div>
            <div className="px-5 pt-2 pb-3 border-b border-[#1a1a1a] flex items-center justify-between flex-shrink-0">
              <p className="text-white font-black text-lg">Add Vehicle</p>
              <button onClick={() => setShowAddVehicle(false)} className="w-8 h-8 bg-[#1a1a1a] rounded-xl flex items-center justify-center">
                <X className="w-3.5 h-3.5 text-gray-500" />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto px-5 py-4 space-y-3" style={{ scrollbarWidth: 'none' }}>
              <Input label="Registration" placeholder="e.g. CA 456-789" />
              <Input label="Make" placeholder="e.g. MAN, Volvo, Mercedes" />
              <Input label="Model" placeholder="e.g. TGX 18.640" />
              <div>
                <label className="text-[11px] text-gray-500 uppercase tracking-widest font-semibold block mb-2">Vehicle Type</label>
                <select className="w-full bg-[#111] border border-[#2a2a2a] rounded-xl px-4 py-3 text-white focus:outline-none focus:border-yellow-400/60 text-sm">
                  <option>Tautliner</option>
                  <option>Rigid 8T</option>
                  <option>Tanker</option>
                  <option>Flatbed</option>
                  <option>Semi-Trailer</option>
                </select>
              </div>
              <Input label="VIN Number" placeholder="17-digit VIN" />
              <Input label="Current Mileage" placeholder="e.g. 245,000 km" />
            </div>
            <div className="px-5 py-4 border-t border-[#1a1a1a] flex-shrink-0">
              <button
                onClick={() => setShowAddVehicle(false)}
                className="w-full bg-yellow-400 text-black py-4 rounded-xl font-black text-sm tracking-widest uppercase active:scale-[0.98] transition-transform"
              >
                Add Vehicle
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
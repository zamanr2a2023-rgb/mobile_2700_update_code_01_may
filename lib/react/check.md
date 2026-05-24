import React, { useState, useEffect } from 'react';
import {
  Briefcase, MapPin, Clock, User, Bell, HelpCircle, LogOut,
  ChevronRight, ChevronLeft, AlertCircle, Check, X, Phone, Star, Zap, Send, Wrench, DollarSign, CheckCircle
} from 'lucide-react';

// Mock Data - Jobs assigned to this mechanic
const ASSIGNED_JOBS = [
  { 
    id: 'TF-8822', 
    vehicle: 'Scania R450', 
    issue: 'Brake system fault', 
    status: 'assigned', 
    urgency: 'urgent', 
    location: 'Birmingham Depot', 
    distance: '2.3 miles',
    time: '15 min ago',
    fleet: 'Logistix Transport',
    fleetContact: '07700 900111',
  },
  { 
    id: 'TF-8823', 
    vehicle: 'Volvo FH16', 
    issue: 'Coolant leak', 
    status: 'in-progress', 
    urgency: 'medium', 
    location: 'Manchester Services', 
    distance: '18 miles',
    time: '1 hr ago',
    fleet: 'Fast Freight Ltd',
    fleetContact: '07700 900222',
  },
];

const COMPLETED_JOBS = [
  { id: 'TF-8820', vehicle: 'DAF XF', issue: 'Engine warning light', completedAt: '2 hrs ago', location: 'M1 Services' },
  { id: 'TF-8819', vehicle: 'Mercedes Actros', issue: 'Battery dead', completedAt: '5 hrs ago', location: 'Birmingham' },
];

// ─── Jobs Feed ────────────────────────────────────────────────────────────────
function EmployeeJobsFeed({ navigateToTracker }: { navigateToTracker: (job: any) => void }) {
  const [activeTab, setActiveTab] = useState<'assigned' | 'completed'>('assigned');

  return (
    <div className="h-full bg-black overflow-y-auto pb-20">
      {/* Header */}
      <div className="bg-[#0f0f0f] border-b border-[#2a2a2a] px-4 py-4">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h1 className="text-white font-black text-xl tracking-tight">My Jobs</h1>
            <p className="text-gray-500 text-xs mt-0.5">Assigned by company</p>
          </div>
          <div className="bg-yellow-400/10 border border-yellow-400/30 px-3 py-1.5 rounded-lg">
            <span className="text-yellow-400 font-black text-sm">{ASSIGNED_JOBS.length}</span>
            <span className="text-yellow-400/80 text-xs ml-1">active</span>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-2">
          <button
            onClick={() => setActiveTab('assigned')}
            className={`flex-1 py-2 rounded-lg text-xs font-bold ${
              activeTab === 'assigned'
                ? 'bg-yellow-400 text-black'
                : 'bg-[#1a1a1a] text-gray-500 border border-[#2a2a2a]'
            }`}
          >
            Assigned ({ASSIGNED_JOBS.length})
          </button>
          <button
            onClick={() => setActiveTab('completed')}
            className={`flex-1 py-2 rounded-lg text-xs font-bold ${
              activeTab === 'completed'
                ? 'bg-yellow-400 text-black'
                : 'bg-[#1a1a1a] text-gray-500 border border-[#2a2a2a]'
            }`}
          >
            Completed ({COMPLETED_JOBS.length})
          </button>
        </div>
      </div>

      <div className="p-4 space-y-3">
        {activeTab === 'assigned' ? (
          <>
            {ASSIGNED_JOBS.map((job) => (
              <div key={job.id} className="bg-[#0f0f0f] border border-[#2a2a2a] rounded-xl p-4">
                <div className="flex items-start justify-between mb-3">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-gray-600 text-xs font-mono">{job.id}</span>
                      <span className={`px-2 py-0.5 rounded text-[10px] font-black ${
                        job.urgency === 'urgent' ? 'bg-red-400/10 text-red-400 border border-red-400/30' :
                        job.urgency === 'high' ? 'bg-orange-400/10 text-orange-400 border border-orange-400/30' :
                        'bg-blue-400/10 text-blue-400 border border-blue-400/30'
                      }`}>
                        {job.urgency.toUpperCase()}
                      </span>
                      <span className={`px-2 py-0.5 rounded text-[10px] font-black ${
                        job.status === 'assigned' ? 'bg-yellow-400/10 text-yellow-400 border border-yellow-400/30' :
                        'bg-green-400/10 text-green-400 border border-green-400/30'
                      }`}>
                        {job.status === 'assigned' ? 'NEW' : 'IN PROGRESS'}
                      </span>
                    </div>
                    <h3 className="text-white font-bold text-sm mb-1">{job.vehicle}</h3>
                    <p className="text-gray-500 text-xs">{job.issue}</p>
                  </div>
                </div>

                <div className="space-y-2 mb-3">
                  <div className="flex items-center gap-2 text-xs">
                    <MapPin className="w-3.5 h-3.5 text-gray-600" />
                    <span className="text-gray-400">{job.location}</span>
                    <span className="text-green-400">• {job.distance}</span>
                  </div>
                  <div className="flex items-center gap-2 text-xs">
                    <User className="w-3.5 h-3.5 text-gray-600" />
                    <span className="text-gray-400">{job.fleet}</span>
                  </div>
                  <div className="flex items-center gap-2 text-xs">
                    <Clock className="w-3.5 h-3.5 text-gray-600" />
                    <span className="text-gray-600">Assigned {job.time}</span>
                  </div>
                </div>

                <div className="flex gap-2">
                  <a
                    href={`tel:${job.fleetContact}`}
                    className="flex-1 bg-[#1a1a1a] border border-[#2a2a2a] text-white py-2.5 rounded-lg text-xs font-bold hover:border-yellow-400/40 transition-colors flex items-center justify-center gap-1.5"
                  >
                    <Phone className="w-3.5 h-3.5" />
                    Call Fleet
                  </a>
                  <button
                    onClick={() => navigateToTracker(job)}
                    className="flex-1 bg-yellow-400 text-black py-2.5 rounded-lg font-black text-xs"
                  >
                    {job.status === 'assigned' ? 'Start Job' : 'Continue'}
                  </button>
                </div>
              </div>
            ))}
          </>
        ) : (
          <>
            {COMPLETED_JOBS.map((job) => (
              <div key={job.id} className="bg-[#0f0f0f] border border-[#2a2a2a] rounded-xl p-4">
                <div className="flex items-start justify-between mb-2">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-gray-600 text-xs font-mono">{job.id}</span>
                      <span className="px-2 py-0.5 rounded text-[10px] font-black bg-green-400/10 text-green-400 border border-green-400/30">
                        ✓ COMPLETE
                      </span>
                    </div>
                    <h3 className="text-white font-bold text-sm mb-1">{job.vehicle}</h3>
                    <p className="text-gray-500 text-xs">{job.issue}</p>
                  </div>
                </div>
                <div className="flex items-center gap-3 text-xs text-gray-600">
                  <div className="flex items-center gap-1">
                    <MapPin className="w-3.5 h-3.5" />
                    <span>{job.location}</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <Clock className="w-3.5 h-3.5" />
                    <span>{job.completedAt}</span>
                  </div>
                </div>
              </div>
            ))}
          </>
        )}
      </div>
    </div>
  );
}

// ─── Job Tracker ──────────────────────────────────────────────────────────────
function EmployeeJobTracker({ job, navigateToJobs }: { job: any; navigateToJobs: () => void }) {
  // Initialize based on job status
  const initialJourneyStarted = job.status === 'in-progress';
  const initialStep = job.status === 'in-progress' ? 2 : 1;
  
  const [currentStep, setCurrentStep] = useState(initialStep);
  const [journeyStarted, setJourneyStarted] = useState(initialJourneyStarted);
  
  const steps = [
    { id: 1, label: 'On Route', completed: journeyStarted && currentStep >= 1 },
    { id: 2, label: 'Arrived', completed: journeyStarted && currentStep >= 2 },
    { id: 3, label: 'Complete', completed: journeyStarted && currentStep >= 3 },
  ];
  
  const handleStartJourney = () => {
    setJourneyStarted(true);
    setCurrentStep(1);
  };
  
  const handleNext = () => {
    if (currentStep < 3) {
      setCurrentStep(currentStep + 1);
    }
  };
  
  const getActionButtonText = () => {
    if (!journeyStarted) return 'START JOURNEY';
    if (currentStep === 1) return "I've Arrived";
    if (currentStep === 2) return 'Mark Complete';
    return 'Finish';
  };

  return (
    <div className="h-full bg-[#080808] flex flex-col">
      {/* Header */}
      <div className="bg-[#0f0f0f] border-b border-[#1a1a1a] px-4 py-4 flex items-center gap-3 flex-shrink-0">
        <button onClick={navigateToJobs} className="w-8 h-8 rounded-xl bg-[#111] border border-[#2a2a2a] flex items-center justify-center">
          <ChevronLeft className="w-4 h-4 text-gray-400" />
        </button>
        <div className="flex-1">
          <h2 className="text-white font-black text-base tracking-tight">{job.vehicle}</h2>
          <p className="text-gray-600 text-xs">{job.id}</p>
        </div>
        <span className={`px-2 py-1 rounded text-[10px] font-black ${
          !journeyStarted 
            ? 'bg-yellow-400/10 text-yellow-400 border border-yellow-400/30'
            : journeyStarted && currentStep < 3
            ? 'bg-orange-400/10 text-orange-400 border border-orange-400/30'
            : 'bg-green-400/10 text-green-400 border border-green-400/30'
        }`}>
          {!journeyStarted ? 'READY' : journeyStarted && currentStep < 3 ? 'IN PROGRESS' : 'COMPLETE'}
        </span>
      </div>

      <div className="flex-1 overflow-y-auto px-4 py-5 space-y-5 pb-24" style={{ scrollbarWidth: 'none' }}>
        {/* Job Details */}
        <div className="bg-[#0f0f0f] border border-[#1a1a1a] rounded-xl p-4">
          <p className="text-yellow-400 text-[10px] font-black uppercase tracking-widest mb-3">Job Details</p>
          <div className="space-y-2.5">
            <div className="flex justify-between">
              <span className="text-gray-500 text-xs">Issue</span>
              <span className="text-white text-xs font-semibold">{job.issue}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500 text-xs">Location</span>
              <span className="text-white text-xs font-semibold">{job.location}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500 text-xs">Fleet Operator</span>
              <span className="text-white text-xs font-semibold">{job.fleet}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500 text-xs">Contact</span>
              <a href={`tel:${job.fleetContact}`} className="text-yellow-400 text-xs font-semibold">{job.fleetContact}</a>
            </div>
          </div>
        </div>

        {/* Progress Steps */}
        <div>
          <p className="text-yellow-400 text-[10px] font-black uppercase tracking-widest mb-3 px-1">Job Progress</p>
          <div className="space-y-2">
            {steps.map((step, idx) => (
              <div key={step.id} className="relative">
                {idx < steps.length - 1 && (
                  <div className={`absolute left-4 top-10 w-0.5 h-6 ${step.completed ? 'bg-green-400' : 'bg-[#1a1a1a]'}`} />
                )}
                <div className={`flex items-center gap-3 p-3 rounded-xl border ${
                  step.completed 
                    ? 'bg-green-400/5 border-green-400/30' 
                    : 'bg-[#0f0f0f] border-[#1a1a1a]'
                }`}>
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                    step.completed 
                      ? 'bg-green-400 text-black' 
                      : 'bg-[#1a1a1a] text-gray-600'
                  }`}>
                    {step.completed ? <Check className="w-4 h-4" strokeWidth={3} /> : <span className="text-xs font-black">{step.id}</span>}
                  </div>
                  <div className="flex-1">
                    <p className={`font-bold text-sm ${step.completed ? 'text-white' : 'text-gray-600'}`}>
                      {step.label}
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Notes */}
        {journeyStarted && currentStep < 3 && (
          <div>
            <p className="text-yellow-400 text-[10px] font-black uppercase tracking-widest mb-3 px-1">Job Notes</p>
            <textarea
              rows={4}
              placeholder="Add notes about the repair..."
              className="w-full bg-[#0f0f0f] border border-[#1a1a1a] rounded-xl px-4 py-3 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-yellow-400/40 resize-none"
            />
          </div>
        )}
      </div>
      
      {/* Fixed Action Button at Bottom */}
      {(!journeyStarted || currentStep < 3) && (
        <div className="flex-shrink-0 bg-[#080808] border-t border-[#1a1a1a] p-4 pb-24">
          <button
            onClick={journeyStarted ? handleNext : handleStartJourney}
            className="w-full bg-yellow-400 text-black py-4 rounded-xl font-black text-sm tracking-wider uppercase flex items-center justify-center gap-2"
          >
            {!journeyStarted && <Zap className="w-5 h-5" />}
            {getActionButtonText()}
          </button>
        </div>
      )}
    </div>
  );
}

// ─── Profile ──────────────────────────────────────────────────────────────────
function EmployeeProfile({ onLogout }: { onLogout?: () => void }) {
  const [notificationsEnabled, setNotificationsEnabled] = useState(true);
  const [showHelpModal, setShowHelpModal] = useState(false);

  return (
    <>
      {showHelpModal && <HelpSupportSheet role="mechanic-employee" onClose={() => setShowHelpModal(false)} />}
    <div className="h-full bg-[#080808] overflow-y-auto pb-20" style={{ scrollbarWidth: 'none' }}>
      {/* Hero Section */}
      <div className="px-5 pt-4 pb-5 flex flex-col items-center">
        <div className="w-20 h-20 rounded-2xl bg-yellow-400/20 border-2 border-yellow-400/30 flex items-center justify-center mb-3">
          <User className="w-10 h-10 text-yellow-400" />
        </div>
        <h2 className="text-white font-black text-lg tracking-tight">John Smith</h2>
        <p className="text-gray-600 text-xs mt-1">Swift Mechanics Ltd</p>
      </div>

      <div className="px-5 space-y-3 pb-8">
        {/* Stats */}
        <div className="grid grid-cols-3 gap-2">
          {[
            { label: 'Jobs Done', value: '45' },
            { label: 'This Week', value: '8' },
            { label: 'Rating', value: '4.8' },
          ].map(({ label, value }) => (
            <div key={label} className="bg-[#0f0f0f] rounded-xl border border-[#1a1a1a] p-3 text-center">
              <p className="text-yellow-400 font-black text-lg">{value}</p>
              <p className="text-gray-600 text-[10px] mt-0.5">{label}</p>
            </div>
          ))}
        </div>

        {/* Personal Details */}
        <div className="bg-[#0f0f0f] rounded-xl border border-[#1a1a1a] overflow-hidden">
          <div className="px-4 py-2.5 border-b border-[#1a1a1a]">
            <p className="text-yellow-400 text-[10px] font-black uppercase tracking-widest">Personal Details</p>
          </div>
          <div className="p-4 space-y-3">
            <div className="space-y-1.5">
              <label className="text-[11px] text-gray-500 uppercase tracking-widest font-semibold">Full Name</label>
              <input defaultValue="John Smith" className="w-full bg-[#111] border border-[#2a2a2a] rounded-xl px-4 py-3 text-white focus:outline-none focus:border-yellow-400/60 text-sm" />
            </div>
            <div className="space-y-1.5">
              <label className="text-[11px] text-gray-500 uppercase tracking-widest font-semibold">Email Address</label>
              <input defaultValue="john.smith@swiftmechanics.co.uk" type="email" className="w-full bg-[#111] border border-[#2a2a2a] rounded-xl px-4 py-3 text-white focus:outline-none focus:border-yellow-400/60 text-sm" />
            </div>
          </div>
        </div>

        {/* Notifications */}
        <div className="bg-[#0f0f0f] rounded-xl border border-[#1a1a1a] overflow-hidden">
          <div className="px-4 py-2.5 border-b border-[#1a1a1a]">
            <p className="text-yellow-400 text-[10px] font-black uppercase tracking-widest">Notifications</p>
          </div>
          <div className="p-4">
            <button
              onClick={() => setNotificationsEnabled(!notificationsEnabled)}
              className="w-full flex items-center justify-between"
            >
              <div className="flex items-center gap-3">
                <Bell className="w-4 h-4 text-yellow-400" />
                <div className="text-left">
                  <p className="text-white text-sm font-semibold">Push Notifications</p>
                  <p className="text-gray-600 text-xs">Get notified of new job assignments</p>
                </div>
              </div>
              <div className={`w-12 h-6 rounded-full transition-colors ${
                notificationsEnabled ? 'bg-yellow-400' : 'bg-[#2a2a2a]'
              }`}>
                <div className={`w-5 h-5 bg-white rounded-full mt-0.5 transition-transform ${
                  notificationsEnabled ? 'ml-6' : 'ml-0.5'
                }`} />
              </div>
            </button>
          </div>
        </div>

        {/* Action Buttons */}
        <button 
          onClick={() => setShowHelpModal(true)}
          className="w-full bg-[#0f0f0f] border border-[#1e1e1e] rounded-xl py-3.5 flex items-center gap-3 px-4 hover:border-yellow-400/30 transition-colors"
        >
          <div className="w-8 h-8 bg-yellow-400/10 rounded-lg flex items-center justify-center flex-shrink-0">
            <HelpCircle className="w-4 h-4 text-yellow-400" />
          </div>
          <div className="flex-1 text-left">
            <p className="text-white text-[12px] font-semibold">Help & Support</p>
            <p className="text-gray-600 text-[10px]">Contact your company admin</p>
          </div>
          <ChevronRight className="w-4 h-4 text-gray-600" />
        </button>

        <button 
          onClick={onLogout}
          className="w-full border border-red-500/20 rounded-xl py-3.5 flex items-center justify-center gap-2 text-red-400 text-[12px] font-semibold bg-red-500/5 active:scale-[0.98] transition-transform"
        >
          <LogOut className="w-4 h-4" /> Log Out
        </button>

        <p className="text-center text-gray-700 text-[10px] pt-1">Employee Account · Managed by Swift Mechanics Ltd</p>
      </div>
    </div>
    </>
  );
}

// ─── Help & Support Sheet ─────────────────────────────────────────────────────────
function HelpSupportSheet({ role, onClose }: { role: 'company' | 'mechanic-employee'; onClose: () => void }) {
  const [category, setCategory] = useState<string | null>(null);
  const [message, setMessage] = useState('');
  const [sent, setSent] = useState(false);

  const categories = [
    { id: 'technical', label: 'Technical Issue', icon: Wrench },
    { id: 'payment',   label: 'Payment / Billing', icon: DollarSign },
    { id: 'account',   label: 'Account & Profile', icon: User },
    { id: 'job',       label: 'Job / Booking',     icon: Briefcase },
    { id: 'other',     label: 'Other',             icon: HelpCircle },
  ];

  if (sent) {
    return (
      <div className="absolute inset-0 bg-black/85 z-50 flex flex-col justify-end" onClick={onClose}>
        <div className="bg-[#0e0e0e] rounded-t-3xl border-t border-[#2a2a2a] p-6 flex flex-col items-center text-center" onClick={e => e.stopPropagation()}>
          <div className="flex justify-center mb-1 pt-1">
            <div className="w-10 h-1 bg-[#333] rounded-full" />
          </div>
          <div className="w-16 h-16 bg-green-400/15 rounded-2xl flex items-center justify-center mb-4 mt-4 border border-green-400/30">
            <CheckCircle className="w-8 h-8 text-green-400" />
          </div>
          <p className="text-white font-black text-[16px] mb-1.5">Message Sent!</p>
          <p className="text-gray-400 text-[12px] leading-relaxed mb-6">Our support team will respond within 24 hours via your registered email address.</p>
          <button onClick={onClose} className="w-full bg-yellow-400 text-black py-3.5 rounded-xl font-black text-[12px] tracking-widest uppercase">
            Done
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="absolute inset-0 bg-black/85 z-50 flex flex-col justify-end" onClick={onClose}>
      <div className="bg-[#0e0e0e] rounded-t-3xl border-t border-[#2a2a2a] flex flex-col max-h-[88%]" onClick={e => e.stopPropagation()}>
        <div className="flex justify-center pt-3 pb-1 flex-shrink-0">
          <div className="w-10 h-1 bg-[#333] rounded-full" />
        </div>
        <div className="px-5 pt-2 pb-4 border-b border-[#1a1a1a] flex items-center justify-between flex-shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-yellow-400/10 rounded-xl border border-yellow-400/20 flex items-center justify-center">
              <HelpCircle className="w-5 h-5 text-yellow-400" />
            </div>
            <div>
              <p className="text-white font-black text-[15px] tracking-tight">Help &amp; Support</p>
              <p className="text-gray-500 text-[10px]">We usually reply within 24 hours</p>
            </div>
          </div>
          <button onClick={onClose} className="w-8 h-8 bg-[#1a1a1a] rounded-xl flex items-center justify-center">
            <X className="w-3.5 h-3.5 text-gray-500" />
          </button>
        </div>
        <div className="overflow-y-auto flex-1 px-5 py-4 space-y-4" style={{ scrollbarWidth: 'none' }}>
          <div>
            <p className="text-gray-500 text-[10px] font-black uppercase tracking-widest mb-2.5">What's this about?</p>
            <div className="grid grid-cols-2 gap-2">
              {categories.map(c => {
                const Icon = c.icon;
                const sel = category === c.id;
                return (
                  <button
                    key={c.id}
                    onClick={() => setCategory(c.id)}
                    className={`flex items-center gap-2.5 px-3 py-3 rounded-xl border transition-all ${sel ? 'border-yellow-400/50 bg-yellow-400/8' : 'border-[#1e1e1e] bg-[#111]'}`}
                  >
                    <Icon className={`w-4 h-4 flex-shrink-0 ${sel ? 'text-yellow-400' : 'text-gray-500'}`} />
                    <span className={`text-[11px] font-semibold text-left ${sel ? 'text-yellow-400' : 'text-gray-400'}`}>{c.label}</span>
                  </button>
                );
              })}
            </div>
          </div>
          <div>
            <p className="text-gray-500 text-[10px] font-black uppercase tracking-widest mb-2.5">Your Message</p>
            <textarea
              value={message}
              onChange={e => setMessage(e.target.value)}
              placeholder="Describe your issue or question in as much detail as possible..."
              rows={5}
              className="w-full bg-[#111] border border-[#2a2a2a] rounded-xl px-4 py-3 text-white placeholder:text-gray-700 focus:outline-none focus:border-yellow-400/40 text-[12px] resize-none leading-relaxed"
            />
            <p className="text-gray-600 text-[10px] mt-1.5">Sent from: {role === 'company' ? 'admin@swiftmechanics.co.uk · Company' : 'john.smith@swiftmechanics.co.uk · Mechanic Employee'}</p>
          </div>
        </div>
        <div className="px-5 pb-5 pt-3 border-t border-[#1a1a1a] flex-shrink-0 space-y-2">
          <button
            onClick={() => { if (category && message.trim()) setSent(true); }}
            className={`w-full py-3.5 rounded-xl font-black text-[12px] tracking-widest uppercase flex items-center justify-center gap-2 transition-opacity ${category && message.trim() ? 'bg-yellow-400 text-black' : 'bg-yellow-400/30 text-black/40 cursor-not-allowed'}`}
          >
            <Send className="w-4 h-4" /> Send Message
          </button>
          <button onClick={onClose} className="w-full py-2.5 text-gray-600 text-[12px] font-semibold">Cancel</button>
        </div>
      </div>
    </div>
  );
}

// ─── Main Export ──────────────────────────────────────────────────────────────
export function MechanicEmployeeApp({ screen: initialScreen, onLogout }: { screen: string; onLogout?: () => void }) {
  const [currentScreen, setCurrentScreen] = useState(initialScreen || 'employee-jobs');
  const [selectedJob, setSelectedJob] = useState<any>(null);
  
  // Sync external navigation (sidebar) with internal state
  React.useEffect(() => {
    setCurrentScreen(initialScreen);
  }, [initialScreen]);
  
  // Navigation helpers
  const navigateToJobs = () => {
    setSelectedJob(null);
    setCurrentScreen('employee-jobs');
  };
  const navigateToTracker = (job: any) => {
    setSelectedJob(job);
    setCurrentScreen('employee-tracker');
  };
  
  // Shared Bottom Tab Bar Component
  const TabBar = ({ activeScreen }: { activeScreen: string }) => {
    const tabs = [
      { id: 'employee-jobs', icon: Briefcase, label: 'My Jobs' },
      { id: 'employee-profile', icon: User, label: 'Profile' },
    ];

    return (
      <div className="flex-shrink-0 bg-[#080808] border-t border-[#1a1a1a] pb-2 pt-1">
        <div className="flex">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeScreen === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setCurrentScreen(tab.id)}
                className="flex-1 flex flex-col items-center gap-1 py-2"
              >
                <div className={`w-7 h-7 rounded-xl flex items-center justify-center transition-colors ${isActive ? 'bg-yellow-400' : ''}`}>
                  <Icon className={`w-3.5 h-3.5 ${isActive ? 'text-black' : 'text-gray-600'}`} strokeWidth={isActive ? 2.5 : 2} />
                </div>
                <span className={`text-[8px] font-semibold transition-colors ${isActive ? 'text-yellow-400' : 'text-gray-700'}`}>
                  {tab.label}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    );
  };

  // Render current screen
  const renderScreen = () => {
    switch (currentScreen) {
      case 'employee-jobs':
        return <EmployeeJobsFeed navigateToTracker={navigateToTracker} />;
      case 'employee-tracker':
        return <EmployeeJobTracker job={selectedJob || ASSIGNED_JOBS[0]} navigateToJobs={navigateToJobs} />;
      case 'employee-profile':
        return <EmployeeProfile onLogout={onLogout} />;
      default:
        return <EmployeeJobsFeed navigateToTracker={navigateToTracker} />;
    }
  };

  return (
    <div className="h-full flex flex-col relative">
      {renderScreen()}
      <TabBar activeScreen={currentScreen} />
    </div>
  );
}
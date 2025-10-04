'use client';

import { useState } from 'react';

export default function AccountDeletion() {
  const [email, setEmail] = useState('');
  const [reason, setReason] = useState('');
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Handle deletion request
    console.log('Deletion request:', { email, reason });
    setSubmitted(true);
  };

  return (
    <div className="min-h-screen">
      {/* Navigation */}
      <nav className="fixed top-0 w-full bg-white/80 backdrop-blur-md z-50 border-b border-honey-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <a href="/" className="flex items-center space-x-2">
            <div className="w-10 h-10 bg-gradient-to-br from-honey-400 to-hive-500 hexagon flex items-center justify-center">
              <span className="text-2xl">🐝</span>
            </div>
            <span className="text-2xl font-bold">
              Habit<span className="text-gradient">Hive</span>
            </span>
          </a>
          <a href="/" className="text-gray-600 hover:text-honey-600 transition-colors">
            Back to Home
          </a>
        </div>
      </nav>

      {/* Content */}
      <div className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <div className="text-center mb-12">
            <h1 className="text-4xl sm:text-5xl font-bold mb-4">
              Account <span className="text-gradient">Deletion</span>
            </h1>
            <p className="text-xl text-gray-600">
              We're sorry to see you go. Manage your account and data below.
            </p>
          </div>

          {/* In-App Instructions */}
          <div className="bg-gradient-to-r from-honey-50 to-hive-50 rounded-2xl p-8 mb-12">
            <div className="flex items-start gap-4 mb-6">
              <div className="text-4xl">📱</div>
              <div>
                <h2 className="text-2xl font-bold mb-2">Delete Account In-App (Recommended)</h2>
                <p className="text-gray-700 leading-relaxed">
                  The fastest way to delete your account is directly from the HabitHive app.
                </p>
              </div>
            </div>

            <div className="bg-white rounded-xl p-6 space-y-4">
              <h3 className="font-bold text-lg mb-4">Step-by-Step Instructions:</h3>
              <ol className="space-y-3">
                {[
                  'Open the HabitHive app on your device',
                  'Tap the "Profile" tab at the bottom right',
                  'Tap "Settings" (gear icon)',
                  'Scroll down and tap "Account"',
                  'Tap "Delete Account"',
                  'Confirm your decision',
                ].map((step, i) => (
                  <li key={i} className="flex items-start gap-3">
                    <span className="w-8 h-8 bg-gradient-to-br from-honey-400 to-hive-500 rounded-full flex items-center justify-center text-white font-bold flex-shrink-0">
                      {i + 1}
                    </span>
                    <span className="text-gray-700 pt-1">{step}</span>
                  </li>
                ))}
              </ol>
            </div>
          </div>

          {/* What Gets Deleted */}
          <div className="bg-white rounded-2xl shadow-lg p-8 mb-12">
            <h2 className="text-2xl font-bold mb-6">What Gets Deleted</h2>
            <div className="grid md:grid-cols-2 gap-6">
              <div>
                <h3 className="font-bold text-lg mb-4 text-red-600 flex items-center gap-2">
                  <span>🗑️</span> Permanently Deleted
                </h3>
                <ul className="space-y-2 text-gray-700">
                  {[
                    'Your account and profile',
                    'All habit data and streaks',
                    'Check-in history',
                    'Personal insights and statistics',
                    'Hive memberships',
                    'Notification preferences',
                    'All personally identifiable information',
                  ].map((item, i) => (
                    <li key={i} className="flex items-start gap-2">
                      <span className="text-red-500 mt-1">✗</span>
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <h3 className="font-bold text-lg mb-4 text-green-600 flex items-center gap-2">
                  <span>💾</span> What We Keep (Anonymized)
                </h3>
                <ul className="space-y-2 text-gray-700">
                  {[
                    'Aggregated usage statistics (anonymous)',
                    'System logs required for security',
                    'Legal compliance records if applicable',
                  ].map((item, i) => (
                    <li key={i} className="flex items-start gap-2">
                      <span className="text-green-500 mt-1">✓</span>
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
                <div className="mt-4 p-4 bg-green-50 rounded-lg">
                  <p className="text-sm text-gray-600">
                    All retained data is anonymized and cannot be traced back to you.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Important Information */}
          <div className="bg-yellow-50 border-l-4 border-yellow-500 rounded-r-xl p-6 mb-12">
            <h3 className="font-bold text-lg mb-3 flex items-center gap-2">
              <span>⚠️</span> Important Information
            </h3>
            <ul className="space-y-2 text-gray-700">
              <li>• Account deletion is <strong>permanent and cannot be undone</strong></li>
              <li>• Processing typically takes <strong>up to 30 days</strong> to complete</li>
              <li>• You will receive a confirmation email when deletion is complete</li>
              <li>• If you're in any Hives, you'll be removed from them</li>
              <li>• Other Hive members will no longer see your profile or data</li>
              <li>• If you change your mind, you must create a new account from scratch</li>
            </ul>
          </div>

          {/* Alternative: Export Data First */}
          <div className="bg-white rounded-2xl shadow-lg p-8 mb-12">
            <h2 className="text-2xl font-bold mb-4">Want to Keep Your Data?</h2>
            <p className="text-gray-700 mb-6 leading-relaxed">
              Before deleting your account, you can export all your data. This gives you a complete backup of
              your habits, streaks, and insights.
            </p>
            <div className="flex flex-col sm:flex-row gap-4">
              <a
                href="mailto:support@habithive.app?subject=Data Export Request"
                className="flex-1 bg-gradient-to-r from-honey-400 to-hive-500 text-white px-6 py-3 rounded-lg font-semibold text-center hover:shadow-lg transition-all"
              >
                📥 Request Data Export
              </a>
              <a
                href="/support"
                className="flex-1 bg-gray-100 text-gray-700 px-6 py-3 rounded-lg font-semibold text-center hover:bg-gray-200 transition-all"
              >
                📧 Contact Support
              </a>
            </div>
          </div>

          {/* Web-Based Deletion Request */}
          <div className="bg-white rounded-2xl shadow-lg p-8">
            <h2 className="text-2xl font-bold mb-4">Request Deletion Online</h2>
            <p className="text-gray-700 mb-6 leading-relaxed">
              Can't access the app? Submit a deletion request here. We'll process it within 48 hours.
            </p>

            {submitted ? (
              <div className="bg-green-50 border-2 border-green-500 rounded-xl p-8 text-center">
                <div className="text-5xl mb-4">✅</div>
                <h3 className="text-2xl font-bold text-green-800 mb-2">Request Submitted</h3>
                <p className="text-green-700 mb-4">
                  We've received your account deletion request. You'll receive a confirmation email within 48 hours.
                </p>
                <p className="text-sm text-gray-600">
                  If you don't receive an email, please check your spam folder or contact support@habithive.app
                </p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-6">
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Email Address (associated with your account)
                  </label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-honey-400 focus:outline-none"
                    placeholder="your.email@example.com"
                    required
                  />
                  <p className="text-sm text-gray-500 mt-2">
                    We'll send a verification email to this address before processing the deletion.
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Reason for Leaving (Optional)
                  </label>
                  <textarea
                    value={reason}
                    onChange={(e) => setReason(e.target.value)}
                    rows={4}
                    className="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-honey-400 focus:outline-none resize-none"
                    placeholder="Help us improve by sharing why you're leaving..."
                  />
                  <p className="text-sm text-gray-500 mt-2">
                    Your feedback helps us make HabitHive better for everyone.
                  </p>
                </div>

                <div className="bg-red-50 border-2 border-red-200 rounded-lg p-4">
                  <label className="flex items-start gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      required
                      className="mt-1 w-5 h-5 text-red-600 border-gray-300 rounded focus:ring-red-500"
                    />
                    <span className="text-sm text-gray-700">
                      I understand that this action is permanent and cannot be undone. All my data, including
                      habits, streaks, Hives, and insights will be permanently deleted.
                    </span>
                  </label>
                </div>

                <button
                  type="submit"
                  className="w-full bg-red-500 text-white px-8 py-4 rounded-lg font-bold text-lg hover:bg-red-600 transition-all"
                >
                  Submit Deletion Request
                </button>
              </form>
            )}
          </div>

          {/* Support Resources */}
          <div className="mt-12 grid md:grid-cols-3 gap-6">
            <div className="bg-white rounded-xl p-6 text-center">
              <div className="text-3xl mb-3">💬</div>
              <h3 className="font-bold mb-2">Need Help?</h3>
              <a href="/support" className="text-honey-600 hover:underline">
                Visit Support Center
              </a>
            </div>
            <div className="bg-white rounded-xl p-6 text-center">
              <div className="text-3xl mb-3">📧</div>
              <h3 className="font-bold mb-2">Email Us</h3>
              <a href="mailto:support@habithive.app" className="text-honey-600 hover:underline">
                support@habithive.app
              </a>
            </div>
            <div className="bg-white rounded-xl p-6 text-center">
              <div className="text-3xl mb-3">🔒</div>
              <h3 className="font-bold mb-2">Privacy Policy</h3>
              <a href="/privacy" className="text-honey-600 hover:underline">
                View Privacy Policy
              </a>
            </div>
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="py-12 px-4 sm:px-6 lg:px-8 bg-white/50 border-t border-honey-200">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row justify-between items-center gap-6">
            <div className="flex items-center space-x-2">
              <div className="w-10 h-10 bg-gradient-to-br from-honey-400 to-hive-500 hexagon flex items-center justify-center">
                <span className="text-2xl">🐝</span>
              </div>
              <span className="text-2xl font-bold">
                Habit<span className="text-gradient">Hive</span>
              </span>
            </div>
            <div className="flex gap-8 text-gray-600">
              <a href="/" className="hover:text-honey-600 transition-colors">Home</a>
              <a href="/privacy" className="hover:text-honey-600 transition-colors">Privacy</a>
              <a href="/terms" className="hover:text-honey-600 transition-colors">Terms</a>
              <a href="/support" className="hover:text-honey-600 transition-colors">Support</a>
            </div>
            <div className="text-gray-600">
              © 2025 HabitHive. All rights reserved.
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}

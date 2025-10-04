'use client';

import { useState } from 'react';

export default function Support() {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    subject: '',
    message: '',
  });
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Handle support ticket submission
    console.log('Support ticket:', formData);
    setSubmitted(true);
    setTimeout(() => {
      setSubmitted(false);
      setFormData({ name: '', email: '', subject: '', message: '' });
    }, 3000);
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
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-12">
            <h1 className="text-4xl sm:text-5xl font-bold mb-4">
              How Can We <span className="text-gradient">Help?</span>
            </h1>
            <p className="text-xl text-gray-600">
              We're here to support you on your habit-building journey
            </p>
          </div>

          <div className="grid lg:grid-cols-3 gap-8 mb-12">
            {/* FAQ Categories */}
            <div className="lg:col-span-3 grid md:grid-cols-3 gap-6">
              <div className="bg-white rounded-2xl shadow-lg p-6 hover:shadow-xl transition-shadow">
                <div className="text-4xl mb-4">📱</div>
                <h3 className="text-xl font-bold mb-2">Getting Started</h3>
                <ul className="space-y-2 text-gray-600">
                  <li>• How to create an account</li>
                  <li>• Adding your first habit</li>
                  <li>• Setting up notifications</li>
                  <li>• Navigating the app</li>
                </ul>
              </div>
              <div className="bg-white rounded-2xl shadow-lg p-6 hover:shadow-xl transition-shadow">
                <div className="text-4xl mb-4">🐝</div>
                <h3 className="text-xl font-bold mb-2">Hives & Social</h3>
                <ul className="space-y-2 text-gray-600">
                  <li>• Creating a Hive</li>
                  <li>• Inviting friends</li>
                  <li>• Understanding leaderboards</li>
                  <li>• Managing Hive settings</li>
                </ul>
              </div>
              <div className="bg-white rounded-2xl shadow-lg p-6 hover:shadow-xl transition-shadow">
                <div className="text-4xl mb-4">🔒</div>
                <h3 className="text-xl font-bold mb-2">Privacy & Account</h3>
                <ul className="space-y-2 text-gray-600">
                  <li>• Managing your data</li>
                  <li>• Deleting your account</li>
                  <li>• Privacy settings</li>
                  <li>• Security tips</li>
                </ul>
              </div>
            </div>
          </div>

          {/* Common Questions */}
          <div className="bg-white rounded-2xl shadow-lg p-8 mb-12">
            <h2 className="text-3xl font-bold mb-6">Frequently Asked Questions</h2>
            <div className="space-y-6">
              {[
                {
                  q: 'How do I delete my account and data?',
                  a: 'You can delete your account from the app by going to Profile > Settings > Account > Delete Account. All your data will be permanently deleted within 30 days. You can also request deletion by contacting support@habithive.app.',
                },
                {
                  q: 'How do I export my data?',
                  a: 'Go to Profile > Settings > Privacy > Export Data. We'll email you a complete copy of your habit data, insights, and Hive information in JSON format within 24 hours.',
                },
                {
                  q: 'Can I use HabitHive without joining a Hive?',
                  a: 'Yes! Hives are optional. You can track habits privately and still get all the benefits of streak tracking, insights, and reminders.',
                },
                {
                  q: 'How many habits can I track?',
                  a: 'You can track unlimited habits. We recommend starting with 3-5 habits to build consistency before adding more.',
                },
                {
                  q: 'How do Hive invites work?',
                  a: 'Each Hive has a unique invite code. Share the code with friends, and they can join from the Hive tab by tapping "Join with Code". Hives support up to 10 members.',
                },
                {
                  q: 'What happens to my streak if I miss a day?',
                  a: 'Your streak will reset to 0. However, your overall completion percentage and history remain intact. You can see all your past streaks in the Insights tab.',
                },
                {
                  q: 'Can I change my notification time?',
                  a: 'Yes! Go to Profile > Settings > Notifications. You can customize reminder times for each individual habit.',
                },
                {
                  q: 'Is HabitHive free?',
                  a: 'Yes, HabitHive is completely free with no ads. We may introduce optional premium features in the future, but core functionality will always be free.',
                },
              ].map((faq, i) => (
                <div key={i} className="border-b border-gray-200 last:border-0 pb-6 last:pb-0">
                  <h3 className="text-lg font-semibold text-gray-800 mb-2">{faq.q}</h3>
                  <p className="text-gray-600 leading-relaxed">{faq.a}</p>
                </div>
              ))}
            </div>
          </div>

          {/* Account & Data Management */}
          <div className="bg-gradient-to-r from-honey-50 to-hive-50 rounded-2xl p-8 mb-12">
            <h2 className="text-3xl font-bold mb-6">Account & Data Management</h2>
            <div className="grid md:grid-cols-2 gap-6">
              <div className="bg-white rounded-xl p-6">
                <h3 className="text-xl font-bold mb-3 flex items-center gap-2">
                  <span>📥</span> Export Your Data
                </h3>
                <p className="text-gray-600 mb-4">
                  Download a complete copy of all your HabitHive data including habits, check-ins, Hives, and insights.
                </p>
                <a
                  href="mailto:support@habithive.app?subject=Data Export Request"
                  className="inline-block bg-gradient-to-r from-honey-400 to-hive-500 text-white px-6 py-2 rounded-lg font-semibold hover:shadow-lg transition-all"
                >
                  Request Export
                </a>
              </div>
              <div className="bg-white rounded-xl p-6">
                <h3 className="text-xl font-bold mb-3 flex items-center gap-2">
                  <span>🗑️</span> Delete Your Account
                </h3>
                <p className="text-gray-600 mb-4">
                  Permanently delete your account and all associated data. This action cannot be undone.
                </p>
                <a
                  href="mailto:support@habithive.app?subject=Account Deletion Request"
                  className="inline-block bg-red-500 text-white px-6 py-2 rounded-lg font-semibold hover:shadow-lg transition-all"
                >
                  Request Deletion
                </a>
              </div>
            </div>
            <div className="mt-6 bg-white rounded-xl p-6">
              <p className="text-sm text-gray-600">
                <strong>Note:</strong> For in-app account management, open HabitHive and go to <strong>Profile → Settings → Account</strong>.
                You can export data or delete your account directly from the app. Email requests are typically processed within 48 hours.
              </p>
            </div>
          </div>

          {/* Contact Form */}
          <div className="bg-white rounded-2xl shadow-lg p-8">
            <h2 className="text-3xl font-bold mb-6">Still Need Help?</h2>
            <p className="text-gray-600 mb-6">
              Can't find what you're looking for? Send us a message and we'll get back to you within 24 hours.
            </p>
            {submitted ? (
              <div className="bg-green-50 border-2 border-green-500 rounded-xl p-8 text-center">
                <div className="text-5xl mb-4">✅</div>
                <h3 className="text-2xl font-bold text-green-800 mb-2">Message Sent!</h3>
                <p className="text-green-700">We'll get back to you within 24 hours.</p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-6">
                <div className="grid md:grid-cols-2 gap-6">
                  <div>
                    <label className="block text-sm font-semibold text-gray-700 mb-2">Name</label>
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      className="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-honey-400 focus:outline-none"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-semibold text-gray-700 mb-2">Email</label>
                    <input
                      type="email"
                      value={formData.email}
                      onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                      className="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-honey-400 focus:outline-none"
                      required
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Subject</label>
                  <select
                    value={formData.subject}
                    onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                    className="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-honey-400 focus:outline-none"
                    required
                  >
                    <option value="">Select a topic</option>
                    <option value="account">Account & Login Issues</option>
                    <option value="hive">Hive & Social Features</option>
                    <option value="data">Data Export or Deletion</option>
                    <option value="bug">Bug Report</option>
                    <option value="feature">Feature Request</option>
                    <option value="other">Other</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Message</label>
                  <textarea
                    value={formData.message}
                    onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                    rows={6}
                    className="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-honey-400 focus:outline-none resize-none"
                    required
                  />
                </div>
                <button
                  type="submit"
                  className="w-full bg-gradient-to-r from-honey-400 to-hive-500 text-white px-8 py-4 rounded-lg font-bold text-lg hover:shadow-lg transition-all hover:scale-105"
                >
                  Send Message
                </button>
              </form>
            )}
          </div>

          {/* Quick Links */}
          <div className="mt-12 grid md:grid-cols-3 gap-6">
            <div className="bg-white rounded-xl p-6 text-center">
              <div className="text-3xl mb-3">📧</div>
              <h3 className="font-bold mb-2">Email Support</h3>
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
            <div className="bg-white rounded-xl p-6 text-center">
              <div className="text-3xl mb-3">📜</div>
              <h3 className="font-bold mb-2">Terms of Service</h3>
              <a href="/terms" className="text-honey-600 hover:underline">
                View Terms
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

'use client';

import { useState } from 'react';

export default function Home() {
  const [email, setEmail] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Handle waitlist signup
    console.log('Email submitted:', email);
    alert('Thanks for joining the waitlist! 🐝');
    setEmail('');
  };

  return (
    <div className="min-h-screen">
      {/* Navigation */}
      <nav className="fixed top-0 w-full bg-white/80 backdrop-blur-md z-50 border-b border-honey-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="flex items-center space-x-2">
            <div className="w-10 h-10 bg-gradient-to-br from-honey-400 to-hive-500 hexagon flex items-center justify-center">
              <span className="text-2xl">🐝</span>
            </div>
            <span className="text-2xl font-bold">
              Habit<span className="text-gradient">Hive</span>
            </span>
          </div>
          <button className="bg-gradient-to-r from-honey-400 to-hive-500 text-white px-6 py-2 rounded-full font-semibold hover:shadow-lg transition-all duration-300 hover:scale-105">
            Get Started
          </button>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            <div className="space-y-8">
              <div className="inline-block">
                <span className="bg-honey-100 text-honey-700 px-4 py-2 rounded-full text-sm font-semibold">
                  🍯 Sweet Success Starts Here
                </span>
              </div>
              <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold leading-tight">
                Build Better Habits{' '}
                <span className="text-gradient">Together</span>
              </h1>
              <p className="text-xl text-gray-600 leading-relaxed">
                Transform your habits with friends. Track, compete, and grow together in your personal Hives. The sweetest way to build lasting habits.
              </p>
              <div className="flex flex-col sm:flex-row gap-4">
                <form onSubmit={handleSubmit} className="flex-1 flex gap-2">
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="Enter your email"
                    className="flex-1 px-4 py-3 rounded-lg border-2 border-honey-200 focus:border-honey-400 focus:outline-none"
                    required
                  />
                  <button
                    type="submit"
                    className="bg-gradient-to-r from-honey-400 to-hive-500 text-white px-6 py-3 rounded-lg font-semibold hover:shadow-lg transition-all duration-300 hover:scale-105"
                  >
                    Join Waitlist
                  </button>
                </form>
              </div>
              <div className="flex items-center gap-8 pt-4">
                <div className="text-center">
                  <div className="text-3xl font-bold text-gradient">10K+</div>
                  <div className="text-sm text-gray-600">Active Users</div>
                </div>
                <div className="text-center">
                  <div className="text-3xl font-bold text-gradient">1M+</div>
                  <div className="text-sm text-gray-600">Habits Tracked</div>
                </div>
                <div className="text-center">
                  <div className="text-3xl font-bold text-gradient">98%</div>
                  <div className="text-sm text-gray-600">Success Rate</div>
                </div>
              </div>
            </div>
            <div className="relative">
              <div className="absolute inset-0 bg-gradient-to-br from-honey-300 to-hive-400 rounded-3xl blur-3xl opacity-30 animate-pulse-slow"></div>
              <div className="relative bg-white rounded-3xl shadow-2xl p-8 space-y-6">
                {/* Honeycomb Grid Visualization */}
                <div className="grid grid-cols-7 gap-1">
                  {Array.from({ length: 35 }).map((_, i) => {
                    const isActive = Math.random() > 0.6;
                    return (
                      <div
                        key={i}
                        className={`hexagon aspect-square ${
                          isActive
                            ? 'bg-gradient-to-br from-honey-400 to-hive-500 animate-float'
                            : 'bg-gray-100'
                        }`}
                        style={{
                          animationDelay: `${i * 0.05}s`,
                        }}
                      />
                    );
                  })}
                </div>
                <div className="bg-gradient-to-r from-honey-50 to-hive-50 rounded-xl p-4">
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-semibold">5 Day Streak</span>
                    <span className="text-2xl">🔥</span>
                  </div>
                  <div className="bg-white rounded-lg p-3 flex items-center justify-between">
                    <span className="text-sm text-gray-600">Floss Hive</span>
                    <span className="text-sm font-semibold text-honey-600">100% Today</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8 bg-white/50">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl sm:text-5xl font-bold mb-4">
              Why <span className="text-gradient">HabitHive</span>?
            </h2>
            <p className="text-xl text-gray-600">Everything you need to build and maintain great habits</p>
          </div>
          <div className="grid md:grid-cols-3 gap-8">
            {[
              {
                icon: '🐝',
                title: 'Create Your Hive',
                description: 'Build accountability groups with friends and family. Share goals and keep each other motivated.',
              },
              {
                icon: '🍯',
                title: 'Track Progress',
                description: 'Visualize your streaks with beautiful honeycomb grids. See your progress at a glance.',
              },
              {
                icon: '🏆',
                title: 'Compete & Grow',
                description: 'Friendly competition with leaderboards. Celebrate wins and support each other.',
              },
              {
                icon: '📊',
                title: 'Deep Insights',
                description: 'Track habits across week, month, and year. Understand your patterns and optimize.',
              },
              {
                icon: '✨',
                title: 'Beautiful Design',
                description: 'Delightful interface that makes habit tracking fun. Emojis, colors, and smooth animations.',
              },
              {
                icon: '🔔',
                title: 'Smart Reminders',
                description: 'Never miss a habit with intelligent notifications. Stay consistent, stay successful.',
              },
            ].map((feature, i) => (
              <div
                key={i}
                className="bg-white rounded-2xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 hover:-translate-y-2"
              >
                <div className="text-5xl mb-4">{feature.icon}</div>
                <h3 className="text-2xl font-bold mb-3">{feature.title}</h3>
                <p className="text-gray-600">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Social Features */}
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            <div className="order-2 lg:order-1">
              <div className="bg-white rounded-3xl shadow-2xl p-8">
                <div className="bg-gradient-to-r from-honey-400 to-hive-500 rounded-2xl p-6 text-white mb-6">
                  <div className="flex items-center gap-3 mb-4">
                    <span className="text-3xl">🦷</span>
                    <div>
                      <h4 className="font-bold text-xl">Floss Hive</h4>
                      <p className="text-sm opacity-90">1 per day goal</p>
                    </div>
                  </div>
                  <div className="flex justify-between text-sm">
                    <div>
                      <div className="font-bold text-2xl">1</div>
                      <div className="opacity-80">Members</div>
                    </div>
                    <div>
                      <div className="font-bold text-2xl">0</div>
                      <div className="opacity-80">Group Streak</div>
                    </div>
                    <div>
                      <div className="font-bold text-2xl">100%</div>
                      <div className="opacity-80">Avg Completion</div>
                    </div>
                  </div>
                </div>
                <div className="space-y-3">
                  <h5 className="font-semibold text-gray-700">Today's Leaders</h5>
                  <div className="bg-gradient-to-r from-honey-50 to-hive-50 rounded-xl p-4 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="bg-gradient-to-br from-honey-400 to-hive-500 w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-xl">
                        B
                      </div>
                      <div>
                        <div className="font-semibold">Bee Venk 2</div>
                        <div className="text-sm text-gray-600">100% today</div>
                      </div>
                    </div>
                    <div className="text-2xl">+1 🍯</div>
                  </div>
                </div>
              </div>
            </div>
            <div className="order-1 lg:order-2 space-y-6">
              <h2 className="text-4xl sm:text-5xl font-bold">
                Stronger <span className="text-gradient">Together</span>
              </h2>
              <p className="text-xl text-gray-600">
                Join or create Hives with friends. Share your journey, compete on leaderboards, and earn honey rewards. Building habits is easier when you're not alone.
              </p>
              <ul className="space-y-4">
                {[
                  'Create unlimited Hives for different habits',
                  'Invite up to 10 friends per Hive',
                  'Real-time progress updates and notifications',
                  'Group streaks and shared achievements',
                  'Private and supportive community',
                ].map((item, i) => (
                  <li key={i} className="flex items-center gap-3">
                    <span className="w-6 h-6 bg-gradient-to-br from-honey-400 to-hive-500 rounded-full flex items-center justify-center text-white">
                      ✓
                    </span>
                    <span className="text-gray-700">{item}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Insights Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8 bg-white/50">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            <div className="space-y-6">
              <h2 className="text-4xl sm:text-5xl font-bold">
                Track Your <span className="text-gradient">Growth</span>
              </h2>
              <p className="text-xl text-gray-600">
                Get powerful insights into your habit patterns. See week, month, and year overviews. Understand what works and optimize your routine.
              </p>
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-gradient-to-br from-honey-400 to-hive-500 rounded-2xl p-6 text-white">
                  <div className="text-4xl font-bold mb-2">57%</div>
                  <div className="text-sm opacity-90">Week Average</div>
                  <div className="text-xs opacity-75">Completion</div>
                </div>
                <div className="bg-gradient-to-br from-pink-400 to-red-400 rounded-2xl p-6 text-white">
                  <div className="text-4xl font-bold mb-2">5</div>
                  <div className="text-sm opacity-90">Current Streak</div>
                  <div className="text-xs opacity-75">Best habit</div>
                </div>
              </div>
            </div>
            <div className="bg-white rounded-3xl shadow-2xl p-8">
              <div className="mb-6">
                <div className="flex gap-2 mb-4">
                  <button className="px-4 py-2 bg-gradient-to-r from-honey-400 to-hive-500 text-white rounded-full text-sm font-semibold">
                    Week
                  </button>
                  <button className="px-4 py-2 bg-gray-100 text-gray-600 rounded-full text-sm font-semibold">
                    Month
                  </button>
                  <button className="px-4 py-2 bg-gray-100 text-gray-600 rounded-full text-sm font-semibold">
                    Year
                  </button>
                </div>
              </div>
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <span className="text-2xl">🏃</span>
                      <span className="font-semibold">Running</span>
                    </div>
                    <span className="text-honey-600 font-bold">86%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-3">
                    <div className="bg-gradient-to-r from-honey-400 to-hive-500 h-3 rounded-full" style={{ width: '86%' }}></div>
                  </div>
                  <div className="text-sm text-gray-500 mt-1">5 streak</div>
                </div>
                <div>
                  <div className="flex justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <span className="text-2xl">🦷</span>
                      <span className="font-semibold">Floss</span>
                    </div>
                    <span className="text-honey-600 font-bold">71%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-3">
                    <div className="bg-gradient-to-r from-honey-400 to-hive-500 h-3 rounded-full" style={{ width: '71%' }}></div>
                  </div>
                  <div className="text-sm text-gray-500 mt-1">3 streak</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto text-center">
          <div className="bg-gradient-to-br from-honey-400 to-hive-500 rounded-3xl p-12 text-white shadow-2xl">
            <h2 className="text-4xl sm:text-5xl font-bold mb-6">
              Ready to Build Better Habits?
            </h2>
            <p className="text-xl mb-8 opacity-90">
              Join thousands of users who are transforming their lives, one habit at a time. Start your journey today!
            </p>
            <form onSubmit={handleSubmit} className="flex flex-col sm:flex-row gap-4 max-w-md mx-auto">
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Enter your email"
                className="flex-1 px-6 py-4 rounded-full text-gray-800 focus:outline-none focus:ring-4 focus:ring-white/30"
                required
              />
              <button
                type="submit"
                className="bg-white text-honey-600 px-8 py-4 rounded-full font-bold hover:shadow-lg transition-all duration-300 hover:scale-105"
              >
                Get Started Free
              </button>
            </form>
            <p className="mt-6 text-sm opacity-75">No credit card required • Free forever</p>
          </div>
        </div>
      </section>

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
              <a href="/privacy" className="hover:text-honey-600 transition-colors">Privacy</a>
              <a href="/terms" className="hover:text-honey-600 transition-colors">Terms</a>
              <a href="/support" className="hover:text-honey-600 transition-colors">Support</a>
              <a href="/account-deletion" className="hover:text-honey-600 transition-colors">Delete Account</a>
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

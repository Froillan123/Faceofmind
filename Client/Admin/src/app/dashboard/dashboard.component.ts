import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '../services/auth.service';
import { WebSocketService, AnalyticsData } from '../services/websocket.service';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration, ChartType } from 'chart.js';
import { catchError, finalize } from 'rxjs/operators';
import { of, Subscription } from 'rxjs';
import { FormsModule } from '@angular/forms';
import { Subject } from 'rxjs';
import { debounceTime } from 'rxjs/operators';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, BaseChartDirective, FormsModule],
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.css']
})
export class DashboardComponent implements OnInit, OnDestroy {
  analytics: AnalyticsData | null = null;
  loading = true;
  error = '';
  fetching = false;
  wsConnected = false;

  filter: 'week' | 'month' | 'year' = 'week';
  chartType: ChartType = 'line';
  
  chartDataAll: ChartConfiguration['data'] = { labels: [], datasets: [] };
  chartDataAdmin: ChartConfiguration['data'] = { labels: [], datasets: [] };
  chartDataProfessional: ChartConfiguration['data'] = { labels: [], datasets: [] };
  chartDataUser: ChartConfiguration['data'] = { labels: [], datasets: [] };

  chartOptions: ChartConfiguration['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: true,
        position: 'top',
        labels: {
          usePointStyle: false,
          padding: 25,
          font: {
            size: 13,
            family: "'Inter', sans-serif",
            weight: 500
          },
          color: '#2d3748'
        }
      },
      tooltip: {
        enabled: true,
        mode: 'index',
        intersect: false,
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        titleFont: { size: 14, family: "'Inter', sans-serif" },
        bodyFont: { size: 12, family: "'Inter', sans-serif" },
        padding: 12,
        cornerRadius: 8
      }
    },
    elements: {
      line: {
        tension: 0.5, // Increased for smoother curves
        borderWidth: 0, // Remove border
        fill: true // Enable fill for gradient effect
      },
      point: {
        radius: 0, // No pinpoints
        hoverRadius: 0,
        backgroundColor: undefined
      }
    },
    scales: {
      x: {
        grid: {
          display: false // Remove x-axis grid for cleaner look
        },
        ticks: {
          font: { size: 12, family: "'Inter', sans-serif" },
          color: '#4a5568'
        }
      },
      y: {
        beginAtZero: true,
        grid: {
          color: 'rgba(203, 213, 224, 0.2)' // Softer grid lines
        },
        ticks: {
          precision: 0,
          font: { size: 12, family: "'Inter', sans-serif" },
          color: '#4a5568'
        }
      }
    },
    animation: {
      duration: 1200,
      easing: 'easeOutCubic' // Smoother animation
    }
  };

  allTimeCounts = { 
    total: 0, 
    admin: 0, 
    professional: 0, 
    regular: 0 
  };

  // Manage Users state
  users: any[] = [];
  activeSection: 'home' | 'manage' | 'reports' | 'feedback' | 'revenue' | 'createAd' = 'home';
  usersTotal = 0;
  usersPage = 1;
  usersPageSize = 15;
  activeUsersCount = 0;

  // User filter state
  usersFilter = { query: '', role: '' };
  usersLoading = false;
  private usersSearch$ = new Subject<void>();

  // Edit user modal state
  editingUser: any = null;
  editingUserStatus: string = '';
  savingStatus = false;
  statusError = '';

  // Dummy data for Reports
  dummyReports = [
    { id: 'RPT-001', title: 'Monthly Usage', date: '2024-05-01', status: 'Completed' },
    { id: 'RPT-002', title: 'User Growth', date: '2024-05-10', status: 'In Progress' },
    { id: 'RPT-003', title: 'System Health', date: '2024-05-15', status: 'Completed' },
    { id: 'RPT-004', title: 'Incident Log', date: '2024-05-20', status: 'Pending' },
  ];

  // Dummy data for Feedback & Complaints
  feedbackList: { comment: string; rating: string }[] = [];

  // Dummy data for Revenue
  dummyRevenue = [
    { payer: 'Acme Corp', email: 'billing@acme.com', amount: 120.00, date: '2024-05-01' },
    { payer: 'Jane Smith', email: 'jane@smith.com', amount: 49.99, date: '2024-05-03' },
    { payer: 'John Doe', email: 'john@doe.com', amount: 99.00, date: '2024-05-07' },
    { payer: 'Mega Inc', email: 'finance@mega.com', amount: 300.00, date: '2024-05-10' },
    { payer: 'Alice Brown', email: 'alice@brown.com', amount: 75.50, date: '2024-05-12' },
    { payer: 'Bob Lee', email: 'bob@lee.com', amount: 60.00, date: '2024-05-15' },
  ];

  // Revenue analytics state
  revenueView: 'month' | 'year' = 'month';
  adsCount = 5000;
  newAds = 3;
  revenueByMonth = [
    { month: 'Jan', value: 3000 },
    { month: 'Feb', value: 1000 },
    { month: 'Mar', value: 5000 },
    { month: 'Apr', value: 2000 },
    { month: 'May', value: 500 },
    { month: 'Jun', value: 6000 },
    { month: 'Jul', value: 300 },
  ];
  totalRevenue = 16800;
  revenueChartLabels = ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
  revenueChartData: ChartConfiguration['data'] = {
    labels: this.revenueChartLabels,
    datasets: [
      {
        data: [2000, 5000, 2000, 500, 6000, 300],
        label: 'Ads',
        backgroundColor: (ctx: any) => {
          const gradient = ctx.chart.ctx.createLinearGradient(0, 0, 0, 200);
          gradient.addColorStop(0, '#6366f1cc');
          gradient.addColorStop(1, '#6366f133');
          return gradient;
        },
        borderColor: '#6366f1',
        borderWidth: 2,
        fill: true,
        tension: 0.4,
        pointRadius: 3,
        pointBackgroundColor: '#6366f1',
      },
      {
        data: [3000, 1000, 5000, 2000, 500, 6000],
        label: 'Revenue',
        backgroundColor: (ctx: any) => {
          const gradient = ctx.chart.ctx.createLinearGradient(0, 0, 0, 200);
          gradient.addColorStop(0, '#10b981cc');
          gradient.addColorStop(1, '#10b98133');
          return gradient;
        },
        borderColor: '#10b981',
        borderWidth: 2,
        fill: true,
        tension: 0.4,
        pointRadius: 3,
        pointBackgroundColor: '#10b981',
      }
    ]
  };

  isDarkMode = false;
  adminName = 'Admin User'; // You can set this dynamically if you have user info
  logoutHover = false;

  // WebSocket subscriptions
  private wsSubscriptions: Subscription[] = [];

  constructor(
    private http: HttpClient,
    private authService: AuthService,
    private router: Router,
    private wsService: WebSocketService
  ) {}

  ngOnInit(): void {
    // Check authentication first
    if (!this.authService.isLoggedIn()) {
      console.log('User not logged in, redirecting to login');
      this.router.navigate(['/']);
      return;
    }

    // Set up WebSocket and fetch data
    this.setupWebSocket();
    this.fetchAllTimeCounts();
    
    // On login, fetch all analytics if not cached
    const cacheWeek = localStorage.getItem('analytics_week');
    const cacheMonth = localStorage.getItem('analytics_month');
    const cacheYear = localStorage.getItem('analytics_year');
    if (!cacheWeek || !cacheMonth || !cacheYear) {
      this.refreshAnalytics();
    } else {
      this.fetchAnalytics();
    }
    
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme) {
      this.isDarkMode = savedTheme === 'dark';
    } else {
      this.isDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
    }
    this.applyTheme();
    this.usersSearch$.pipe(debounceTime(400)).subscribe(() => {
      this.fetchUsers();
    });
  }

  ngOnDestroy(): void {
    // Clean up WebSocket subscriptions
    this.wsSubscriptions.forEach(sub => sub.unsubscribe());
    this.wsService.destroy();
  }

  private setupWebSocket(): void {
    // Subscribe to WebSocket analytics updates
    this.wsSubscriptions.push(
      this.wsService.analytics$.subscribe(data => {
        if (data) {
          this.processAnalyticsData(data);
          this.loading = false;
          this.fetching = false;
        }
      })
    );

    // Subscribe to connection status
    this.wsSubscriptions.push(
      this.wsService.connectionStatus$.subscribe(connected => {
        this.wsConnected = connected;
        if (!connected && this.loading) {
          // Fallback to HTTP if WebSocket is not available
          this.fetchAnalytics();
        }
      })
    );

    // Subscribe to notifications
    this.wsSubscriptions.push(
      this.wsService.notifications$.subscribe(message => {
        this.showToast(message, 'success');
      })
    );

    // Subscribe to errors
    this.wsSubscriptions.push(
      this.wsService.errors$.subscribe(error => {
        if (error) {
          console.error('WebSocket error:', error);
          // Fallback to HTTP on WebSocket errors
          if (this.loading) {
            this.fetchAnalytics();
          }
        }
      })
    );
  }

  setFilter(filter: 'week' | 'month' | 'year'): void {
    if (this.filter !== filter) {
      this.filter = filter;
      this.loading = true;
      
      // Try WebSocket first, fallback to HTTP
      if (this.wsConnected) {
        this.wsService.requestAnalytics(filter);
      } else {
        this.fetchAnalytics();
      }
    }
  }

  fetchAnalytics(): void {
    if (this.fetching) return;
    this.error = '';
    const cacheKey = `analytics_${this.filter}`;
    const cached = localStorage.getItem(cacheKey);
    let usedCached = false;
    
    if (cached) {
      try {
        const parsed = JSON.parse(cached);
        if (parsed && parsed.timestamp && parsed.data) {
          this.processAnalyticsData(parsed.data);
          usedCached = true;
        }
      } catch (e) {}
    }
    
    this.loading = !usedCached;
    this.fetching = true;
    
    this.http.get<any>(`/api/user-analytics/?period=${this.filter}`).toPromise().then((data) => {
      if (data) localStorage.setItem(cacheKey, JSON.stringify({ timestamp: Date.now(), data }));
      this.processAnalyticsData(data);
    }).catch((err) => {
      if (!usedCached) {
        this.error = 'Failed to load analytics. Please try again.';
      }
    }).finally(() => {
      this.loading = false;
      this.fetching = false;
    });
  }

  fetchAllTimeCounts(): void {
    this.http.get<AnalyticsData>('/api/user-analytics/?period=all')
      .pipe(catchError(() => of(null)))
      .subscribe((data) => {
        if (data) {
          this.allTimeCounts = {
            total: data.total_users,
            admin: data.admin_count,
            professional: data.professional_count,
            regular: data.regular_count
          };
        }
      });
  }

  private processAnalyticsData(data: AnalyticsData): void {
    this.analytics = data;
    
    let formattedLabels = [...data.labels];
    if (this.filter === 'month') {
      formattedLabels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    } else if (this.filter === 'year') {
      formattedLabels = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
    }

    // Helper function to create gradient fill
    const createGradient = (color: string) => {
      return (ctx: { chart: { ctx: CanvasRenderingContext2D } }) => {
        const gradient = ctx.chart.ctx.createLinearGradient(0, 0, 0, 200);
        gradient.addColorStop(0, `${color}cc`); // More opaque at top
        gradient.addColorStop(1, `${color}33`); // More transparent at bottom
        return gradient;
      };
    };

    this.chartDataAll = {
      labels: formattedLabels,
      datasets: [{
        data: data.data_all,
        label: 'All Users',
        backgroundColor: createGradient('#3b82f6'), // Blue gradient
        borderWidth: 0,
        fill: true,
      }]
    };

    this.chartDataAdmin = {
      labels: formattedLabels,
      datasets: [{
        data: data.data_admin,
        label: 'Admins',
        backgroundColor: createGradient('#8b5cf6'), // Purple gradient
        borderWidth: 0,
        fill: true,
      }]
    };

    this.chartDataProfessional = {
      labels: formattedLabels,
      datasets: [{
        data: data.data_professional,
        label: 'Professionals',
        backgroundColor: createGradient('#10b981'), // Green gradient
        borderWidth: 0,
        fill: true,
      }]
    };

    this.chartDataUser = {
      labels: formattedLabels,
      datasets: [{
        data: data.data_user,
        label: 'Regular Users',
        backgroundColor: createGradient('#f59e0b'), // Yellow gradient
        borderWidth: 0,
        fill: true,
      }]
    };
  }

  logout(): void {
    // Disconnect WebSocket before logout
    this.wsService.disconnect();
    
    const token = this.authService.getToken();
    if (token) {
      this.http.post('/api/admin-logout/', {}, {
        headers: { Authorization: `Bearer ${token}` }
      }).subscribe({
        next: () => {
          this.finishLogout();
        },
        error: () => {
          this.finishLogout();
        }
      });
    } else {
      this.finishLogout();
    }
  }

  private finishLogout() {
    ['week', 'month', 'year'].forEach(period => {
      localStorage.removeItem(`analytics_${period}`);
    });
    this.authService.logout();
    this.router.navigate(['/']);
  }

  setSection(section: 'home' | 'manage' | 'reports' | 'feedback' | 'revenue' | 'createAd') {
    this.activeSection = section;
    if (section === 'manage') {
      this.usersPage = 1;
      this.fetchUsers();
    }
    if (section === 'feedback') {
      this.fetchFeedback();
    }
  }

  async fetchUsers(): Promise<void> {
    this.usersLoading = true;
    let params = `page=${this.usersPage}&page_size=${this.usersPageSize}`;
    if (this.usersFilter.query) params += `&query=${encodeURIComponent(this.usersFilter.query)}`;
    if (this.usersFilter.role) params += `&role=${encodeURIComponent(this.usersFilter.role)}`;
    try {
      const data = await this.http.get<any>(`/api/Get-All-User?${params}`).toPromise();
      this.users = data.results;
      this.usersTotal = data.total;
      this.usersPage = data.page;
      this.usersPageSize = data.page_size;
      this.activeUsersCount = data.active_users_count;
    } catch (err) {
      this.users = [];
      this.usersTotal = 0;
    } finally {
      this.usersLoading = false;
    }
  }

  applyUsersFilter() {
    this.usersPage = 1;
    this.usersSearch$.next();
  }

  clearUsersFilter() {
    this.usersFilter = { query: '', role: '' };
    this.usersPage = 1;
    this.usersSearch$.next();
  }

  nextUsersPage() {
    if ((this.usersPage * this.usersPageSize) < this.usersTotal) {
      this.usersPage++;
      this.fetchUsers();
    }
  }

  prevUsersPage() {
    if (this.usersPage > 1) {
      this.usersPage--;
      this.fetchUsers();
    }
  }

  get usersTotalPages(): number {
    return Math.ceil(this.usersTotal / this.usersPageSize);
  }

  openEditUser(user: any) {
    this.editingUser = { ...user };
    this.editingUserStatus = user.status;
    this.statusError = '';
  }

  closeEditUser() {
    this.editingUser = null;
    this.editingUserStatus = '';
    this.statusError = '';
  }

  saveUserStatus() {
    if (!this.editingUser) return;
    this.savingStatus = true;
    this.statusError = '';
    console.log('Editing user:', this.editingUser);
    const userId = this.editingUser.id || this.editingUser.pk || this.editingUser._id;
    if (!userId) {
      console.error('No user id found in editingUser:', this.editingUser);
      this.statusError = 'User ID not found. Cannot update status.';
      this.savingStatus = false;
      return;
    }
    const payload = {
      id: userId,
      status: this.editingUserStatus
    };
    console.log('PATCH payload:', payload);
    this.http.patch<any>('/api/api/user-status/', {
      ...payload
    }).pipe(finalize(() => this.savingStatus = false)).subscribe({
      next: (res) => {
        this.closeEditUser();
        this.fetchUsers();
      },
      error: (err) => {
        console.error('User status update error:', err);
        this.statusError = err?.error?.error || 'Failed to update status.';
        this.showToast(this.statusError, 'error');
      }
    });
  }

  showToast(message: string, type: 'success' | 'error' = 'success') {
    const toast = document.createElement('div');
    toast.className = type === 'success' ? 'success-toast' : 'error-toast';
    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(() => {
      toast.remove();
    }, 4000);
  }

  createAdvertisement() {
    this.showToast('Advertisement created (dummy action).', 'success');
  }

  setRevenueView(view: 'month' | 'year') {
    this.revenueView = view;
    // Optionally update chart/data here
  }

  refreshAnalytics() {
    this.fetching = true;
    // Remove all analytics caches
    ['week', 'month', 'year'].forEach(period => {
      localStorage.removeItem(`analytics_${period}`);
    });
    
    // Try WebSocket first, fallback to HTTP
    if (this.wsConnected) {
      // Request all periods via WebSocket
      ['week', 'month', 'year'].forEach(period => {
        this.wsService.requestAnalytics(period as any);
      });
    } else {
      // Fallback to HTTP
      this.http.get<any>('/api/all-user-analytics/').toPromise().then((allData) => {
        if (allData.week) localStorage.setItem('analytics_week', JSON.stringify({ timestamp: Date.now(), data: allData.week }));
        if (allData.month) localStorage.setItem('analytics_month', JSON.stringify({ timestamp: Date.now(), data: allData.month }));
        if (allData.year) localStorage.setItem('analytics_year', JSON.stringify({ timestamp: Date.now(), data: allData.year }));
        this.fetchAnalytics();
      }).finally(() => {
        this.fetching = false;
      });
    }
  }

  toggleDarkMode() {
    this.isDarkMode = !this.isDarkMode;
    localStorage.setItem('theme', this.isDarkMode ? 'dark' : 'light');
    this.applyTheme();
  }

  applyTheme() {
    if (this.isDarkMode) {
      document.querySelector('html')?.setAttribute('data-theme', 'dark');
    } else {
      document.querySelector('html')?.setAttribute('data-theme', 'light');
    }
  }

  fetchFeedback() {
    this.http.get<{ comment: string; rating: string }[]>('/api/feedback-list/').subscribe({
      next: (data) => {
        this.feedbackList = data;
      },
      error: (err) => {
        this.feedbackList = [];
      }
    });
  }

  // Helper to extract star count from rating string
  getStarCount(rating: string): number {
    const num = parseInt(rating);
    if (!isNaN(num) && num >= 1 && num <= 5) {
      return num;
    }
    // fallback: try to extract from '5 stars' or similar
    const match = rating && rating.match(/(\d+)/);
    if (match) {
      const val = parseInt(match[1], 10);
      if (!isNaN(val) && val >= 1 && val <= 5) return val;
    }
    return 0;
  }
}
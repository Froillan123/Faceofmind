import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '../services/auth.service';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration, ChartType } from 'chart.js';
import { catchError, finalize } from 'rxjs/operators';
import { of } from 'rxjs';
import { FormsModule } from '@angular/forms';

interface AnalyticsData {
  labels: string[];
  data_all: number[];
  data_admin: number[];
  data_professional: number[];
  data_user: number[];
  total_users: number;
  new_users: number;
  admin_count: number;
  professional_count: number;
  regular_count: number;
  start_date: string;
  end_date: string;
  period: string;
  group_by: string;
}

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, BaseChartDirective, FormsModule],
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.css']
})
export class DashboardComponent implements OnInit {
  analytics: AnalyticsData | null = null;
  loading = true;
  error = '';

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
  activeSection: 'home' | 'manage' = 'home';
  usersTotal = 0;
  usersPage = 1;
  usersPageSize = 15;

  // Edit user modal state
  editingUser: any = null;
  editingUserStatus: string = '';
  savingStatus = false;
  statusError = '';

  constructor(
    private http: HttpClient,
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    if (!this.authService.isLoggedIn()) {
      this.router.navigate(['/']);
      return;
    }
    this.fetchAllTimeCounts();
    this.fetchAnalytics();
  }

  setFilter(filter: 'week' | 'month' | 'year'): void {
    if (this.filter !== filter) {
      this.filter = filter;
      this.fetchAnalytics();
    }
  }

  fetchAnalytics(): void {
    this.loading = true;
    this.error = '';
    const cacheKey = `analytics_${this.filter}`;
    const cached = localStorage.getItem(cacheKey);
    if (cached) {
      try {
        const parsed = JSON.parse(cached);
        if (parsed && parsed.timestamp && parsed.data) {
          const now = Date.now();
          if (now - parsed.timestamp < 5 * 60 * 1000) { // 5 minutes
            this.processAnalyticsData(parsed.data);
            this.loading = false;
            return;
          }
        }
      } catch (e) {}
    }
    this.http.get<AnalyticsData>(`/api/user-analytics/?period=${this.filter}`)
      .pipe(
        catchError(err => {
          console.error('Error fetching analytics:', err);
          this.error = 'Failed to load analytics. Please try again.';
          return of(null);
        }),
        finalize(() => {
          this.loading = false;
        })
      )
      .subscribe({
        next: (data) => {
          if (data) {
            this.processAnalyticsData(data);
            try {
              localStorage.setItem(cacheKey, JSON.stringify({
                timestamp: Date.now(),
                data: data
              }));
            } catch (e) {}
          }
        }
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
    this.authService.logout();
    this.router.navigate(['/']);
  }

  setSection(section: 'home' | 'manage') {
    this.activeSection = section;
    if (section === 'manage') {
      this.usersPage = 1;
      this.fetchUsers();
    }
  }

  fetchUsers(): void {
    this.http.get<any>(`/api/Get-All-User?page=${this.usersPage}&page_size=${this.usersPageSize}`).subscribe({
      next: (data) => {
        this.users = data.results;
        this.usersTotal = data.total;
        this.usersPage = data.page;
        this.usersPageSize = data.page_size;
      },
      error: (err) => {
        this.users = [];
        this.usersTotal = 0;
      }
    });
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
        this.showToast('User status updated successfully.', 'success');
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
}
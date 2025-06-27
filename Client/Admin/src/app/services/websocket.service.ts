import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable, Subject } from 'rxjs';
import { AuthService } from './auth.service';

function isBrowser(): boolean {
  return typeof window !== 'undefined';
}

export interface AnalyticsData {
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
  group_by?: string;
}

export interface WebSocketMessage {
  type: string;
  data?: AnalyticsData;
  period?: string;
  message?: string;
}

@Injectable({
  providedIn: 'root'
})
export class WebSocketService {
  private socket: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000; // Start with 1 second
  private isConnecting = false;
  private shouldReconnect = true;

  // Subjects for different message types
  private analyticsSubject = new BehaviorSubject<AnalyticsData | null>(null);
  private notificationSubject = new Subject<string>();
  private connectionStatusSubject = new BehaviorSubject<boolean>(false);
  private errorSubject = new Subject<string>();

  // Public observables
  public analytics$ = this.analyticsSubject.asObservable();
  public notifications$ = this.notificationSubject.asObservable();
  public connectionStatus$ = this.connectionStatusSubject.asObservable();
  public errors$ = this.errorSubject.asObservable();

  constructor(private authService: AuthService) {
    // Auto-connect when service is created
    this.connect();
  }

  connect(): void {
    if (!isBrowser()) {
      return;
    }
    if (this.isConnecting || this.socket?.readyState === WebSocket.OPEN) {
      return;
    }

    this.isConnecting = true;
    
    // Get the current host for WebSocket URL
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;
    
    // In development, use the same host but different port for WebSocket
    // The proxy doesn't handle WebSocket, so we need to connect directly to Django
    const wsUrl = `${protocol}//${host.replace('4200', '8000')}/ws/analytics/`;

    try {
      this.socket = new WebSocket(wsUrl);
      
      this.socket.onopen = () => {
        console.log('WebSocket connected');
        this.isConnecting = false;
        this.reconnectAttempts = 0;
        this.reconnectDelay = 1000;
        this.connectionStatusSubject.next(true);
        this.errorSubject.next('');
        
        // Send authentication if needed
        this.sendMessage({ type: 'ping' });
      };

      this.socket.onmessage = (event) => {
        try {
          const message: WebSocketMessage = JSON.parse(event.data);
          this.handleMessage(message);
        } catch (error) {
          console.error('Error parsing WebSocket message:', error);
          this.errorSubject.next('Invalid message format');
        }
      };

      this.socket.onclose = (event) => {
        console.log('WebSocket disconnected:', event.code, event.reason);
        this.isConnecting = false;
        this.connectionStatusSubject.next(false);
        
        if (this.shouldReconnect && this.reconnectAttempts < this.maxReconnectAttempts) {
          this.scheduleReconnect();
        }
      };

      this.socket.onerror = (error) => {
        console.error('WebSocket error:', error);
        this.isConnecting = false;
        this.errorSubject.next('WebSocket connection error');
        
        // In development, don't show error if server is not running
        if (isBrowser() && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')) {
          console.log('WebSocket not available in development - using HTTP fallback');
          this.errorSubject.next(''); // Clear error for development
        }
      };

    } catch (error) {
      console.error('Error creating WebSocket:', error);
      this.isConnecting = false;
      this.errorSubject.next('Failed to create WebSocket connection');
    }
  }

  private handleMessage(message: WebSocketMessage): void {
    switch (message.type) {
      case 'analytics_update':
        if (message.data) {
          this.analyticsSubject.next(message.data);
        }
        break;
      
      case 'analytics_notification':
        if (message.message) {
          this.notificationSubject.next(message.message);
        }
        break;
      
      case 'pong':
        // Keep-alive response
        break;
      
      case 'error':
        if (message.message) {
          this.errorSubject.next(message.message);
        }
        break;
      
      default:
        console.log('Unknown message type:', message.type);
    }
  }

  private scheduleReconnect(): void {
    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1); // Exponential backoff
    
    console.log(`Scheduling reconnect attempt ${this.reconnectAttempts} in ${delay}ms`);
    
    setTimeout(() => {
      if (this.shouldReconnect && this.authService.isLoggedIn()) {
        this.connect();
      }
    }, delay);
  }

  sendMessage(message: any): void {
    if (!isBrowser()) {
      return;
    }
    if (this.socket?.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify(message));
    } else {
      console.warn('WebSocket is not connected. Message not sent:', message);
    }
  }

  requestAnalytics(period: 'week' | 'month' | 'year' | 'all'): void {
    this.sendMessage({
      type: 'request_analytics',
      period: period
    });
  }

  ping(): void {
    this.sendMessage({ type: 'ping' });
  }

  disconnect(): void {
    this.shouldReconnect = false;
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
    this.connectionStatusSubject.next(false);
  }

  reconnect(): void {
    this.shouldReconnect = true;
    this.reconnectAttempts = 0;
    this.connect();
  }

  // Cleanup method
  destroy(): void {
    this.disconnect();
    this.analyticsSubject.complete();
    this.notificationSubject.complete();
    this.connectionStatusSubject.complete();
    this.errorSubject.complete();
  }
} 
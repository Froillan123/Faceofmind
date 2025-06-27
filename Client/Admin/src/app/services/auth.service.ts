import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

function isBrowser(): boolean {
  return typeof window !== 'undefined' && !!window.localStorage;
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private loginUrl = '/api/admin-login/';

  constructor(private http: HttpClient) {}

  login(username: string, password: string, rememberMe: boolean): Observable<any> {
    return this.http.post<any>(this.loginUrl, { email: username, password }).pipe(
      tap(res => {
        if (isBrowser() && res.access && res.refresh) {
          localStorage.setItem('access', res.access);
          localStorage.setItem('refresh', res.refresh);
        }
      })
    );
  }

  isLoggedIn(): boolean {
    return isBrowser() && !!localStorage.getItem('access');
  }

  logout(): void {
    if (isBrowser()) {
      localStorage.removeItem('access');
      localStorage.removeItem('refresh');
    }
  }

  getToken(): string | null {
    return isBrowser() ? localStorage.getItem('access') : null;
  }
}
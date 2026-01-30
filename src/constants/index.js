export const APP_NAME = import.meta.env.VITE_APP_NAME || 'CIH App';
export const APP_VERSION = import.meta.env.VITE_APP_VERSION || '1.0.0';
export const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000/api';
export const NODE_ENV = import.meta.env.VITE_NODE_ENV || 'development';

export const ROUTES = {
  HOME: '/',
  ABOUT: '/about',
  CONTACT: '/contact',
  // Add your routes here
};

export const API_ENDPOINTS = {
  USERS: '/users',
  AUTH: '/auth',
  // Add your API endpoints here
};

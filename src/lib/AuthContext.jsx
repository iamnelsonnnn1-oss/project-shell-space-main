import { createContext, useContext, useMemo } from 'react';

// Auth provider selection is a pending Captain decision. This boundary stays
// provider-agnostic: a provider supplies { user, status, signOut }.
const unconfigured = { user: null, status: 'unconfigured', signOut: async () => {} };

const AuthContext = createContext(unconfigured);

export function AuthProvider({ value, children }) {
  const memo = useMemo(() => value ?? unconfigured, [value]);
  return <AuthContext.Provider value={memo}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);

//! `std` locks taken whatever a panicking holder left behind.
//!
//! A panic while a lock is held poisons it, and `.lock().unwrap()` then
//! panics in every later caller: one bad request would take a feature down
//! until the agent restarts. What these locks guard is kept consistent by
//! each holder before it can panic, so the value is used as it is.

use std::sync::{Mutex, MutexGuard, PoisonError, RwLock, RwLockReadGuard, RwLockWriteGuard};

pub trait LockExt<T: ?Sized> {
    fn locked(&self) -> MutexGuard<'_, T>;
}

impl<T: ?Sized> LockExt<T> for Mutex<T> {
    fn locked(&self) -> MutexGuard<'_, T> {
        self.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

pub trait RwLockExt<T: ?Sized> {
    fn read_locked(&self) -> RwLockReadGuard<'_, T>;
    fn write_locked(&self) -> RwLockWriteGuard<'_, T>;
}

impl<T: ?Sized> RwLockExt<T> for RwLock<T> {
    fn read_locked(&self) -> RwLockReadGuard<'_, T> {
        self.read().unwrap_or_else(PoisonError::into_inner)
    }

    fn write_locked(&self) -> RwLockWriteGuard<'_, T> {
        self.write().unwrap_or_else(PoisonError::into_inner)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_poisoned_lock_is_still_taken() {
        let m = std::sync::Arc::new(Mutex::new(1));
        let held = m.clone();
        let _ = std::thread::spawn(move || {
            let _guard = held.lock().unwrap();
            panic!("poison");
        })
        .join();
        assert!(m.is_poisoned());
        *m.locked() += 1;
        assert_eq!(*m.locked(), 2);

        let rw = std::sync::Arc::new(RwLock::new(1));
        let held = rw.clone();
        let _ = std::thread::spawn(move || {
            let _guard = held.write().unwrap();
            panic!("poison");
        })
        .join();
        *rw.write_locked() += 1;
        assert_eq!(*rw.read_locked(), 2);
    }
}

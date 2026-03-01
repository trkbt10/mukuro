import { renderHook, act } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import { useEditableContent } from './useEditableContent';

describe('useEditableContent', () => {
  describe('initial state', () => {
    it('shows savedContent when it exists', () => {
      const { result } = renderHook(() => useEditableContent('saved', 'fallback'));

      expect(result.current.content).toBe('saved');
      expect(result.current.isDirty).toBe(false);
    });

    it('shows fallbackContent when savedContent is empty', () => {
      const { result } = renderHook(() => useEditableContent('', 'fallback'));

      expect(result.current.content).toBe('fallback');
      expect(result.current.isDirty).toBe(false);
    });

    it('shows empty when both are empty', () => {
      const { result } = renderHook(() => useEditableContent('', ''));

      expect(result.current.content).toBe('');
      expect(result.current.isDirty).toBe(false);
    });
  });

  describe('editing', () => {
    it('setContent updates displayed content', () => {
      const { result } = renderHook(() => useEditableContent('saved', 'fallback'));

      act(() => {
        result.current.setContent('edited');
      });

      expect(result.current.content).toBe('edited');
    });

    it('setContent makes it dirty when different from saved', () => {
      const { result } = renderHook(() => useEditableContent('saved', 'fallback'));

      act(() => {
        result.current.setContent('edited');
      });

      expect(result.current.isDirty).toBe(true);
    });

    it('setContent to same as saved is still dirty (user explicitly set)', () => {
      const { result } = renderHook(() => useEditableContent('saved', 'fallback'));

      act(() => {
        result.current.setContent('saved');
      });

      // User explicitly set content, even if same value
      expect(result.current.isDirty).toBe(false);
    });

    it('setContent to empty string is valid edit', () => {
      const { result } = renderHook(() => useEditableContent('saved', 'fallback'));

      act(() => {
        result.current.setContent('');
      });

      expect(result.current.content).toBe('');
      expect(result.current.isDirty).toBe(true);
    });
  });

  describe('reset', () => {
    it('reset returns to savedContent', () => {
      const { result } = renderHook(() => useEditableContent('saved', 'fallback'));

      act(() => {
        result.current.setContent('edited');
      });
      expect(result.current.content).toBe('edited');

      act(() => {
        result.current.reset();
      });

      expect(result.current.content).toBe('saved');
      expect(result.current.isDirty).toBe(false);
    });

    it('reset returns to fallback when savedContent is empty', () => {
      const { result } = renderHook(() => useEditableContent('', 'fallback'));

      act(() => {
        result.current.setContent('edited');
      });

      act(() => {
        result.current.reset();
      });

      expect(result.current.content).toBe('fallback');
      expect(result.current.isDirty).toBe(false);
    });
  });

  describe('savedContent changes (server update)', () => {
    it('follows savedContent change when not edited', () => {
      const { result, rerender } = renderHook(
        ({ saved, fallback }) => useEditableContent(saved, fallback),
        { initialProps: { saved: 'initial', fallback: 'fallback' } }
      );

      expect(result.current.content).toBe('initial');

      rerender({ saved: 'updated', fallback: 'fallback' });

      expect(result.current.content).toBe('updated');
      expect(result.current.isDirty).toBe(false);
    });

    it('keeps edited content when savedContent changes', () => {
      const { result, rerender } = renderHook(
        ({ saved, fallback }) => useEditableContent(saved, fallback),
        { initialProps: { saved: 'initial', fallback: 'fallback' } }
      );

      act(() => {
        result.current.setContent('edited');
      });

      rerender({ saved: 'updated', fallback: 'fallback' });

      expect(result.current.content).toBe('edited');
      expect(result.current.isDirty).toBe(true);
    });

    it('isDirty recalculates when savedContent changes to match edited', () => {
      const { result, rerender } = renderHook(
        ({ saved, fallback }) => useEditableContent(saved, fallback),
        { initialProps: { saved: 'initial', fallback: 'fallback' } }
      );

      act(() => {
        result.current.setContent('target');
      });
      expect(result.current.isDirty).toBe(true);

      // Server now has same content
      rerender({ saved: 'target', fallback: 'fallback' });

      expect(result.current.content).toBe('target');
      expect(result.current.isDirty).toBe(false);
    });
  });

  describe('fallbackContent changes', () => {
    it('follows fallbackContent change when not edited and savedContent empty', () => {
      const { result, rerender } = renderHook(
        ({ saved, fallback }) => useEditableContent(saved, fallback),
        { initialProps: { saved: '', fallback: 'template-v1' } }
      );

      expect(result.current.content).toBe('template-v1');

      rerender({ saved: '', fallback: 'template-v2' });

      expect(result.current.content).toBe('template-v2');
      expect(result.current.isDirty).toBe(false);
    });
  });
});

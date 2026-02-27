import type { ReactNode } from 'react';
import { Button } from './Button';
import { Modal } from './Modal';

export interface DeleteConfirmModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: ReactNode;
  onConfirm: () => void;
  isPending?: boolean;
}

export function DeleteConfirmModal({
  open,
  onClose,
  title,
  description,
  children,
  onConfirm,
  isPending,
}: DeleteConfirmModalProps) {
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={title}
      description={description}
      size="sm"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>Cancel</Button>
          <Button variant="danger" onClick={onConfirm} loading={isPending}>Delete</Button>
        </>
      }
    >
      {children}
    </Modal>
  );
}

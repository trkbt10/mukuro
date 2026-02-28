/**
 * Hook that parses markdown content into structured blocks using
 * react-editor-ui's streaming markdown parser.
 *
 * Supports both complete messages and future streaming deltas.
 */
import { useState, useEffect } from 'react';
import { createStreamingMarkdownParser } from 'react-editor-ui/parsers/Markdown';
import type {
  MarkdownParseEvent,
  EndEvent,
  MarkdownElementMetadata,
} from 'react-editor-ui/parsers/Markdown';

export type ParsedBlock = {
  id: string;
  type: string;
  content: string;
  metadata?: MarkdownElementMetadata;
};

function handleEvent(
  event: MarkdownParseEvent,
  pending: Map<string, ParsedBlock>,
  finished: ParsedBlock[],
): void {
  if (event.type === 'begin') {
    pending.set(event.elementId, {
      id: event.elementId,
      type: event.elementType,
      content: '',
      metadata: event.metadata,
    });
    return;
  }
  if (event.type === 'delta') {
    const block = pending.get(event.elementId);
    if (block) {
      block.content += event.content;
    }
    return;
  }
  if (event.type === 'end') {
    const endEvent = event as EndEvent;
    const block = pending.get(endEvent.elementId);
    if (block) {
      block.content = endEvent.finalContent;
      finished.push(block);
      pending.delete(endEvent.elementId);
    }
  }
}

async function parseMarkdown(text: string): Promise<ParsedBlock[]> {
  const parser = createStreamingMarkdownParser();
  const pending = new Map<string, ParsedBlock>();
  const finished: ParsedBlock[] = [];

  for await (const event of parser.processChunk(text)) {
    handleEvent(event, pending, finished);
  }
  for await (const event of parser.complete()) {
    handleEvent(event, pending, finished);
  }

  return finished;
}

/** Parse markdown text into blocks, memoized by content string. */
export function useMarkdownBlocks(content: string): ParsedBlock[] {
  const [blocks, setBlocks] = useState<ParsedBlock[]>([]);

  useEffect(() => {
    let cancelled = false;
    parseMarkdown(content).then((result) => {
      if (!cancelled) setBlocks(result);
    });
    return () => { cancelled = true; };
  }, [content]);

  return blocks;
}

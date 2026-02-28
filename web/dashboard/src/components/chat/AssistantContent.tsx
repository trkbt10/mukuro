import { memo } from 'react';
import { MarkdownViewer } from 'react-editor-ui/viewers/MarkdownViewer';
import { parseTable } from 'react-editor-ui/parsers/Markdown';
import { useMarkdownBlocks, type ParsedBlock } from '@/hooks/useMarkdownParser';
import styles from './AssistantContent.module.css';

function BlockView({ block }: { block: ParsedBlock }) {
  if (block.type === 'horizontal_rule') {
    return <hr className={styles.mdHr} />;
  }

  if (block.type === 'code') {
    const lang = (block.metadata?.language as string) ?? '';
    return (
      <div className={styles.mdCodeBlock}>
        {lang && lang !== 'text' && (
          <span className={styles.mdCodeLang}>{lang}</span>
        )}
        <pre className={styles.mdPre}>
          <code>{block.content}</code>
        </pre>
      </div>
    );
  }

  if (block.type === 'table') {
    const parsed = parseTable(block.content);
    if (parsed) {
      return (
        <table className={styles.mdTable}>
          <thead>
            <tr>
              {parsed.headers.map((h, i) => (
                <th key={i} style={{ textAlign: parsed.alignments[i] ?? 'left' }}>
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {parsed.rows.map((row, ri) => (
              <tr key={ri}>
                {row.map((cell, ci) => (
                  <td key={ci} style={{ textAlign: parsed.alignments[ci] ?? 'left' }}>
                    {cell}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      );
    }
    return <pre className={styles.mdPre}>{block.content}</pre>;
  }

  if (block.type === 'list') {
    const lines = block.content.split('\n').filter(Boolean);
    const Tag = block.metadata?.ordered ? 'ol' : 'ul';
    return (
      <Tag className={styles.mdList}>
        {lines.map((line, i) => (
          <li key={i}>{line}</li>
        ))}
      </Tag>
    );
  }

  if (block.type === 'header') {
    const level = (block.metadata?.level as number) ?? 1;
    const Tag = `h${Math.min(level, 6)}` as 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6';
    return <Tag className={styles.mdHeader}>{block.content}</Tag>;
  }

  if (block.type === 'quote') {
    return <blockquote className={styles.mdQuote}>{block.content}</blockquote>;
  }

  // text / other
  return <p className={styles.mdText}>{block.content}</p>;
}

export const AssistantContent = memo(function AssistantContent({
  content,
}: {
  content: string;
}) {
  const blocks = useMarkdownBlocks(content);
  return (
    <MarkdownViewer value={content} className={styles.markdown}>
      {blocks.map((block) => (
        <BlockView key={block.id} block={block} />
      ))}
    </MarkdownViewer>
  );
});

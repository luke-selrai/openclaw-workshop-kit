#!/usr/bin/env node
const fs = require('fs');

function validateSkillHeader(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const errors = [];

  // Find SkillHeader component usage
  const allLines = content.split('\n');
  const startIdx = allLines.findIndex(l => l.includes('<SkillHeader'));
  if (startIdx === -1) return errors;
  let endIdx = startIdx;
  while (endIdx < allLines.length && !allLines[endIdx].trim().endsWith('/>')) {
    endIdx++;
  }
  const headerText = allLines.slice(startIdx, endIdx + 1).join('\n');
  const lineNum = startIdx + 1;

  // Check for correct prop: fileName (not skillId)
  if (headerText.includes('skillId=')) {
    errors.push({
      line: lineNum,
      issue: 'Uses "skillId" prop instead of "fileName"',
      fix: 'Change skillId="..." to fileName="..."'
    });
  }

  // Check for removed props (difficulty, category, tags)
  const deprecatedProps = ['difficulty', 'category', 'tags'];
  deprecatedProps.forEach(prop => {
    if (headerText.includes(`${prop}=`)) {
      errors.push({
        line: lineNum,
        issue: `Uses deprecated "${prop}" prop`,
        fix: `Remove ${prop} prop (only use: skillName, fileName, description)`
      });
    }
  });

  // Check for required props
  if (!headerText.includes('skillName=')) {
    errors.push({
      line: lineNum,
      issue: 'Missing required "skillName" prop'
    });
  }

  if (!headerText.includes('fileName=')) {
    errors.push({
      line: lineNum,
      issue: 'Missing required "fileName" prop'
    });
  }

  if (!headerText.includes('description=')) {
    errors.push({
      line: lineNum,
      issue: 'Missing required "description" prop'
    });
  }

  return errors;
}

const files = process.argv.slice(2);
let totalErrors = 0;

if (files.length === 0) {
  console.error('Usage: validate-skill-props.js <file1.md> [file2.md...]');
  process.exit(1);
}

files.forEach(file => {
  if (!fs.existsSync(file)) {
    console.error(`File not found: ${file}`);
    return;
  }

  const errors = validateSkillHeader(file);
  if (errors.length > 0) {
    console.error(`❌ ${file}:`);
    errors.forEach(err => {
      console.error(`   Line ${err.line}: ${err.issue}`);
      if (err.fix) console.error(`   Fix: ${err.fix}`);
    });
    totalErrors += errors.length;
  }
});

if (totalErrors > 0) {
  console.error(`\n❌ Found ${totalErrors} SkillHeader prop error(s)`);
  process.exit(1);
} else {
  console.log('✅ SkillHeader props validated successfully');
  process.exit(0);
}

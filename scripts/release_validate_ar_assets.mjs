import { readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();

const jsonFiles = [
  'docs/ar/unity_try_on_payload.schema.json',
  'docs/ar/fit_score_request.schema.json',
  'docs/ar/samples/try_on_product_response.sample.json',
  'docs/ar/samples/fit_score_response.sample.json',
];

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function isUrl(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return false;
  }
  try {
    const parsed = new URL(value);
    return ['http:', 'https:'].includes(parsed.protocol);
  } catch {
    return false;
  }
}

async function readJson(relativePath) {
  const absolute = path.join(root, relativePath);
  const content = await readFile(absolute, 'utf8');
  return JSON.parse(content);
}

async function main() {
  console.log('[release:ar-assets] validating AR JSON artifacts...');
  const parsed = {};
  for (const file of jsonFiles) {
    parsed[file] = await readJson(file);
  }

  const tryOn = parsed['docs/ar/samples/try_on_product_response.sample.json'];
  assert(typeof tryOn.id === 'string' && tryOn.id, 'try_on sample missing id');
  assert(typeof tryOn.templateId === 'string' && tryOn.templateId, 'try_on sample missing templateId');
  assert(tryOn.garmentConfig && typeof tryOn.garmentConfig === 'object', 'try_on sample missing garmentConfig');
  assert(tryOn.template && typeof tryOn.template === 'object', 'try_on sample missing template');
  assert(isUrl(tryOn.model3d), 'try_on sample model3d must be valid URL');
  assert(isUrl(tryOn.unityAssetBundleUrl), 'try_on sample unityAssetBundleUrl must be valid URL');

  const lodModels = tryOn.garmentConfig?.lodModels || {};
  assert(isUrl(lodModels.lod0), 'garmentConfig.lodModels.lod0 must be valid URL');
  if (lodModels.lod1) assert(isUrl(lodModels.lod1), 'garmentConfig.lodModels.lod1 must be valid URL');
  if (lodModels.lod2) assert(isUrl(lodModels.lod2), 'garmentConfig.lodModels.lod2 must be valid URL');

  if (tryOn.garmentConfig?.fabricTextureUrl) {
    assert(isUrl(tryOn.garmentConfig.fabricTextureUrl), 'fabricTextureUrl must be valid URL');
  }

  const fitScore = parsed['docs/ar/samples/fit_score_response.sample.json'];
  assert(typeof fitScore.recommendedSize === 'string' && fitScore.recommendedSize, 'fit_score sample missing recommendedSize');
  assert(typeof fitScore.fitScore === 'number', 'fit_score sample missing fitScore');
  assert(typeof fitScore.confidence === 'number', 'fit_score sample missing confidence');
  assert(typeof fitScore.fitLabel === 'string' && fitScore.fitLabel, 'fit_score sample missing fitLabel');

  console.log('[release:ar-assets] validation passed.');
}

main().catch((error) => {
  console.error('[release:ar-assets] failed:', error.message);
  process.exitCode = 1;
});

import asyncio
from dataclasses import dataclass
from typing import Optional


@dataclass
class BatchResult:
    success: bool
    items: list[str]
    error: Optional[str]


async def process_batch(batch: list[str], concurrency: int) -> BatchResult:
    sem = asyncio.Semaphore(concurrency)
    async def worker(item: str) -> Optional[str]:
        async with sem:
            try:
                result = await transform(item)
                return result
            except TransformError as e:
                log.error(f"transform failed: {e}")
                return None
    tasks = [worker(item) for item in batch]
    results = await asyncio.gather(*tasks)
    ok = [r for r in results if r is not None]
    return BatchResult(success=len(ok) == len(batch), items=ok, error=None)

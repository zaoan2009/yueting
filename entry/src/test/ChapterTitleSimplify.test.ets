import { describe, it, expect } from '@ohos/hypium';
import { ChapterTitleSimplify } from '../main/ets/utils/ChapterTitleSimplify';

export default function chapterTitleSimplifyTest() {
  describe('ChapterTitleSimplify', () => {
    it('strips_shared_bilibili_style_prefix', 0, () => {
      const prefix = ChapterTitleSimplify.commonPrefix([
        '《棺香美人》一口气看完，超长连更。已更新至1892章',
        '《棺香美人》一口气看完，超长连更 【5.24】 1893~1906',
        '《棺香美人》一口气看完，超长连更 【5.31】 1907~1921'
      ]);
      expect(prefix).assertEqual('《棺香美人》一口气看完，超长连更');
      expect(ChapterTitleSimplify.displayTitle(
        '《棺香美人》一口气看完，超长连更 【5.24】 1893~1906', prefix, true))
        .assertEqual('【5.24】 1893~1906');
      expect(ChapterTitleSimplify.displayTitle(
        '《棺香美人》一口气看完，超长连更。已更新至1892章', prefix, true))
        .assertEqual('已更新至1892章');
    });

    it('keeps_full_title_when_disabled_or_no_prefix', 0, () => {
      expect(ChapterTitleSimplify.displayTitle('第一章 开端', '', true)).assertEqual('第一章 开端');
      expect(ChapterTitleSimplify.displayTitle('第一章 开端', '第一', false)).assertEqual('第一章 开端');
      expect(ChapterTitleSimplify.commonPrefix(['第一章', '第二章'])).assertEqual('');
    });
  });
}

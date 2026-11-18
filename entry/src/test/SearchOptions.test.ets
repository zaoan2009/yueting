import { describe, it, expect } from '@ohos/hypium';
import { Book } from '../main/ets/model/Book';
import { SearchOptions } from '../main/ets/utils/SearchOptions';

function bookOf(title: string, author: string = '', sourceUrl: string = 's'): Book {
  const chapters: Book['chapters'] = [];
  return {
    id: `${sourceUrl}#${title}`,
    title: title,
    author: author,
    narrator: '',
    cover: '',
    category: '',
    intro: '',
    totalDuration: 0,
    chapterCount: 0,
    rating: 0,
    tags: [],
    chapters: chapters,
    bookUrl: title,
    sourceUrl: sourceUrl,
    contentType: 'audio'
  };
}

export default function searchOptionsTest() {
  describe('SearchOptionsRank', () => {
    it('exact_and_core_title_outrank_partial_matches', 0, () => {
      const keyword = '棺香美人';
      const ranked = SearchOptions.rankBooks([
        bookOf('香美人', '铁木冰冰', 'kuwo'),
        bookOf('香草美人', '陈香水', 'kuwo'),
        bookOf('夏日', '香草美人', 'kuwo'),
        bookOf('书香美人', '晨曦公主', 'kuwo'),
        bookOf('棺香美人, 第1集', '影视精彩现', 'bili'),
        bookOf('《棺香美人》完整版', '杏儿追书社', 'bili2')
      ], keyword);
      expect(ranked[0].title.indexOf('棺香美人') >= 0).assertTrue();
      expect(ranked[1].title.indexOf('棺香美人') >= 0).assertTrue();
      expect(ranked[0].sourceUrl === 'bili' || ranked[0].sourceUrl === 'bili2').assertTrue();
      expect(ranked[ranked.length - 1].title === '夏日' || ranked[ranked.length - 1].title === '香美人' ||
        ranked[ranked.length - 1].title.indexOf('棺香美人') < 0).assertTrue();
    });

    it('same_tier_keeps_earlier_arrival_first', 0, () => {
      const ranked = SearchOptions.rankBooks([
        bookOf('棺香美人', '甲', 'first'),
        bookOf('棺香美人', '乙', 'second')
      ], '棺香美人');
      expect(ranked[0].sourceUrl).assertEqual('first');
      expect(ranked[1].sourceUrl).assertEqual('second');
    });

    it('normalize_core_title_strips_episode_tail', 0, () => {
      const normalized = SearchOptions.normalizeSearchText('棺香美人, 第12集');
      expect(SearchOptions.normalizeCoreTitle(normalized)).assertEqual('棺香美人');
    });
  });
}

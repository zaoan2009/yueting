// 听书卡片 UI - 2x2；银杏主题色板借鉴（天青/落叶金），抽象渐变底，不用插画原图。
// 卡片侧不能 import media/audio,所有播控通过 postCardAction call 事件回到 EntryAbility
let playerCardStorage = new LocalStorage();

@Entry(playerCardStorage)
@Component
struct PlayerCard {
  @LocalStorageProp('wearableLayout') wearableLayout: boolean = false;
  @LocalStorageProp('hasBook') hasBook: boolean = false;
  @LocalStorageProp('bookId') bookId: string = '';
  @LocalStorageProp('bookTitle') bookTitle: string = '没有正在播放';
  @LocalStorageProp('author') author: string = '';
  @LocalStorageProp('cover') cover: string = '';
  @LocalStorageProp('imgName') imgName: string = '';
  @LocalStorageProp('chapterTitle') chapterTitle: string = '';
  @LocalStorageProp('isPlaying') isPlaying: boolean = false;

  private readonly ginkgoGold: string = '#E8B02E';
  private readonly ginkgoInk: string = '#2A2210';
  private readonly ginkgoCream: string = '#FFF8E4';
  private readonly ginkgoSky: string = '#B0DCEB';

  private postCall(method: string): void {
    postCardAction(this, {
      action: 'call',
      abilityName: 'EntryAbility',
      params: { method: method }
    });
  }

  /** 点击卡片信息区时打开当前书的播放页；无播放记录时回到应用主页。 */
  private openPlayer(): void {
    const target: string = this.hasBook && this.bookId.length > 0 ? 'player' : 'home';
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: {
        from: 'widget',
        target: target,
        bookId: this.bookId
      }
    });
  }

  private hasCover(): boolean {
    return this.imgName.length > 0 || this.cover.length > 0;
  }

  build() {
    Stack() {
      if (this.wearableLayout) {
        this.WearableLayout()
      } else {
        Stack() {
          // 抽象银杏色渐变；有封面时叠模糊书封。
          Column()
            .width('100%')
            .height('100%')
            .linearGradient({
              angle: 160,
              colors: this.isPlaying ?
                [[this.ginkgoSky, 0], [this.ginkgoGold, 1]] :
                [[this.ginkgoSky, 0], ['#F6E2A0', 1]]
            })
          if (this.hasCover()) {
            if (this.imgName.length > 0) {
              Image('memory://' + this.imgName)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .sourceSize({ width: 120, height: 120 })
                .blur(36)
                .opacity(0.45)
            } else {
              Image(this.cover)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .sourceSize({ width: 120, height: 120 })
                .blur(36)
                .opacity(0.45)
            }
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(this.isPlaying ? '#552A2210' : '#332A2210')
          }

          Column() {
            Row() {
              Stack() {
                if (this.hasCover()) {
                  if (this.imgName.length > 0) {
                    Image('memory://' + this.imgName)
                      .width('100%')
                      .height('100%')
                      .borderRadius(12)
                      .objectFit(ImageFit.Cover)
                      .syncLoad(true)
                  } else {
                    Image(this.cover)
                      .width('100%')
                      .height('100%')
                      .borderRadius(12)
                      .objectFit(ImageFit.Cover)
                      .syncLoad(true)
                      .alt($r('app.media.theme_ginkgo_cover'))
                  }
                } else {
                  Column() {
                    Text('听')
                      .fontSize(22)
                      .fontColor(this.ginkgoInk)
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')
                  .height('100%')
                  .borderRadius(12)
                  .backgroundColor(this.ginkgoCream)
                  .justifyContent(FlexAlign.Center)
                }
              }
              .width(60)
              .height(60)
              .backgroundColor(Color.Transparent)
              .borderRadius(12)
              .clip(true)
              .border({
                width: this.isPlaying ? 1.5 : 0,
                color: this.ginkgoGold
              })

              Column() {
                Text(this.bookTitle)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.hasCover() ? this.ginkgoCream : this.ginkgoInk)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .lineHeight(16)
                if (this.author.length > 0) {
                  Text(this.author)
                    .fontSize(10)
                    .fontColor(this.hasCover() ? '#D9FFF8E4' : '#997A6840')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .margin({ top: 2 })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 10 })
            }
            .width('100%')
            .onClick(() => this.openPlayer())

            Blank()
              .width('100%')
              .onClick(() => this.openPlayer())

            if (this.chapterTitle.length > 0) {
              Text(this.chapterTitle)
                .fontSize(11)
                .fontColor(this.hasCover() ? '#E6FFF8E4' : '#997A6840')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .onClick(() => this.openPlayer())
            }

            Row() {
              this.PlainBtn($r('sys.symbol.backward_end_fill'), 'prev')
              Stack() {
                SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
                  .fontSize(22)
                  .fontColor([this.ginkgoInk])
              }
              .width(40)
              .height(40)
              .borderRadius(20)
              .backgroundColor(this.isPlaying ? this.ginkgoGold : this.ginkgoCream)
              .shadow({
                radius: this.isPlaying ? 10 : 0,
                color: this.isPlaying ? '#66E8B02E' : '#00000000',
                offsetX: 0,
                offsetY: this.isPlaying ? 2 : 0
              })
              .onClick(() => {
                if (!this.hasBook) {
                  this.openPlayer();
                  return;
                }
                this.postCall(this.isPlaying ? 'pause' : 'play');
              })
              this.PlainBtn($r('sys.symbol.forward_end_fill'), 'next')
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ top: 8 })
          }
          .width('100%')
          .height('100%')
          .padding(12)
        }
        .width('100%')
        .height('100%')
        .clip(true)
      }
    }.width('100%').height('100%')
  }

  @Builder
  private WearableLayout() {
    Column({ space: 6 }) {
      Text(this.hasBook && this.bookTitle.length > 0 ? this.bookTitle : $r('app.string.watch_title'))
        .fontSize(16).minFontSize(12).maxFontSize(16)
        .fontWeight(FontWeight.Bold).fontColor(this.ginkgoInk)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center).width('100%').layoutWeight(1)
        .onClick((): void => { this.openPlayer(); })
      Row() {
        this.WearableControl($r('sys.symbol.backward_end_fill'), 'prev', false)
        this.WearableControl(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'),
          this.isPlaying ? 'pause' : 'play', true)
        this.WearableControl($r('sys.symbol.forward_end_fill'), 'next', false)
      }.width('100%').height(38).flexShrink(0)
    }.width('100%').height('100%').padding({ top: 12, bottom: 12, left: 10, right: 10 })
      .linearGradient({
        angle: 160,
        colors: [[this.ginkgoSky, 0], [this.ginkgoGold, 1]]
      })
      .clip(true)
  }

  @Builder
  private WearableControl(icon: Resource, method: string, primary: boolean) {
    Stack() {
      SymbolGlyph(icon).fontSize(20).fontColor([primary ? this.ginkgoInk : this.ginkgoInk])
        .width(34).height(34).borderRadius(17)
        .backgroundColor(primary ? (this.isPlaying ? this.ginkgoGold : this.ginkgoCream) : '#33FFFFFF')
    }.layoutWeight(1).height('100%').onClick((): void => {
      if (this.hasBook) this.postCall(method);
      else this.openPlayer();
    })
  }

  @Builder
  PlainBtn(icon: Resource, method: string) {
    Stack() {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.hasCover() ? this.ginkgoCream : this.ginkgoInk])
    }
    .width(36)
    .height(36)
    .onClick(() => {
      if (!this.hasBook) {
        this.openPlayer();
        return;
      }
      this.postCall(method);
    })
  }
}

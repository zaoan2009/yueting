/** 内置主题定义。资源随应用发布，书籍图片与阅读纸张不属于套装数据。 */
export class AppThemeBundle {
  id: string;
  name: ResourceStr;
  description: ResourceStr;
  accent: string;
  material: number;

  constructor(id: string, name: ResourceStr, description: ResourceStr, accent: string, material: number) {
    this.id = id;
    this.name = name;
    this.description = description;
    this.accent = accent;
    this.material = material;
  }
}

/** 一条记录保存整个外观选择；颜色与自定义背景为用户当前实际选择。 */
export class AppThemeSelection {
  schemaVersion: number = 2;
  /** 产品默认银杏；旧套装 ID 读取时迁到银杏。 */
  themeBundleId: string = 'ginkgo-winter';
  accentColor: string = '#8B6914';
  materialStyle: number = 3;
  /** 空串使用银杏资源色。 */
  backgroundColor: string = '';
  surfaceColor: string = '';
  textColor: string = '';
  /** filesDir/theme_bg 下文件名；空则使用银杏暗纹。图片本身不进备份。 */
  customBackgroundName: string = '';

  constructor(themeBundleId: string = 'ginkgo-winter', accentColor: string = '#8B6914',
    materialStyle: number = 3, backgroundColor: string = '', surfaceColor: string = '',
    textColor: string = '', customBackgroundName: string = '') {
    this.themeBundleId = themeBundleId;
    this.accentColor = accentColor;
    this.materialStyle = materialStyle;
    this.backgroundColor = backgroundColor;
    this.surfaceColor = surfaceColor;
    this.textColor = textColor;
    this.customBackgroundName = customBackgroundName;
  }
}

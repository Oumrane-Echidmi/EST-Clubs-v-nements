import {
  IsBoolean,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
export class ProfileDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  firstName?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  lastName?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  studentId?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl({
    require_tld: false,
    protocols: ['http', 'https'],
    require_protocol: true,
  })
  @MaxLength(2048)
  avatarUrl?: string;
}
export class PreferencesDto {
  @ApiPropertyOptional() @IsOptional() @IsBoolean() notifyNewEvents?: boolean;
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  notifyRegistrations?: boolean;
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  notifyEventUpdates?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() notifyReminders?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() pushEnabled?: boolean;
}
export class PasswordDto {
  @ApiProperty() @IsString() @MaxLength(72) currentPassword!: string;
  @ApiProperty()
  @IsString()
  @MaxLength(72)
  @Matches(/^(?=.*[A-Za-z])(?=.*[0-9]).{8,72}$/)
  password!: string;
}

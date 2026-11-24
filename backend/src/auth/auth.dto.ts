import {
  IsEmail,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  Matches,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
export class EmailDto {
  @ApiProperty({ example: 'student@est.example.edu' })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail()
  @MaxLength(254)
  email!: string;
}
export class LoginDto extends EmailDto {
  @ApiProperty({ minLength: 8, maxLength: 72 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string;
}
export class RegisterDto extends LoginDto {
  @ApiProperty({
    minLength: 8,
    maxLength: 72,
    pattern: '^(?=.*[A-Za-z])(?=.*[0-9]).{8,72}$',
  })
  @Matches(/^(?=.*[A-Za-z])(?=.*[0-9]).{8,72}$/)
  declare password: string;
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(80) firstName!: string;
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(80) lastName!: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  studentId?: string;
}
export class RefreshDto {
  @ApiProperty() @IsString() @Matches(/^[a-f0-9]{96}$/) refreshToken!: string;
}
export class LogoutDto extends RefreshDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(4096)
  deviceToken?: string;
}
export class ResetDto {
  @ApiProperty() @IsString() @Matches(/^[a-f0-9]{96}$/) token!: string;
  @ApiProperty({ minLength: 8, maxLength: 72 })
  @IsString()
  @MaxLength(72)
  @Matches(/^(?=.*[A-Za-z])(?=.*[0-9]).{8,72}$/)
  password!: string;
}
